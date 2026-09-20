#!/usr/bin/env python3
"""Validate the kit's packaging. Runs offline, unauthenticated, in a few milliseconds.

This is the repository's first automated check. It exists because `claude plugin validate`
is schema-only: it passed cleanly on a catalog whose Grok half used an invented key and
was not installable at all. Everything here is a defect that has actually occurred in this
repository, not a hypothetical.

Usage:  python3 scripts/validate-kit.py [--budget-only]
Exit:   0 all checks pass, 1 otherwise.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Description bytes that load into every session, per package. Budgeted rather than
# token-counted because the token figure needs an installed plugin, which needs auth and
# network. Description bytes are ~0.63x the reported always-on token cost — not a 1:1
# proxy, but monotonic with it, so a regression here is a regression there.
BUDGETS = {"core": 3000, "overlay": 1500}

PACKAGES = {
    "core": {
        "root": ROOT,
        "skills": ROOT / "skills",
        "manifests": [ROOT / "plugin.json",
                      ROOT / ".claude-plugin" / "plugin.json",
                      ROOT / ".grok-plugin" / "plugin.json"],
    },
    "overlay": {
        "root": ROOT / "plugins" / "blueprint",
        "skills": ROOT / "plugins" / "blueprint" / "skills",
        "manifests": [ROOT / "plugins" / "blueprint" / ".claude-plugin" / "plugin.json",
                      ROOT / "plugins" / "blueprint" / ".grok-plugin" / "plugin.json"],
    },
}
CATALOGS = [ROOT / ".claude-plugin" / "marketplace.json",
            ROOT / ".grok-plugin" / "marketplace.json"]

failures: list[str] = []
notes: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)


def frontmatter(path: pathlib.Path) -> str:
    parts = path.read_text(errors="replace").split("---\n", 2)
    return parts[1] if len(parts) >= 3 else ""


def description_of(path: pathlib.Path) -> str:
    m = re.search(r"^description:\s*(.+?)(?=\n[a-z-]+:|\Z)", frontmatter(path), re.M | re.S)
    return m.group(1).strip() if m else ""


def check_manifests_parse() -> None:
    for pkg in PACKAGES.values():
        for m in pkg["manifests"]:
            if not m.exists():
                fail(f"missing manifest: {m.relative_to(ROOT)}")
            else:
                try:
                    json.loads(m.read_text())
                except json.JSONDecodeError as e:
                    fail(f"unparseable manifest {m.relative_to(ROOT)}: {e}")
    for c in CATALOGS:
        if not c.exists():
            fail(f"missing catalog: {c.relative_to(ROOT)}")
        else:
            try:
                json.loads(c.read_text())
            except json.JSONDecodeError as e:
                fail(f"unparseable catalog {c.relative_to(ROOT)}: {e}")


def check_version_parity() -> None:
    for name, pkg in PACKAGES.items():
        versions = {}
        for m in pkg["manifests"]:
            if m.exists():
                try:
                    versions[str(m.relative_to(ROOT))] = json.loads(m.read_text()).get("version")
                except json.JSONDecodeError:
                    pass
        distinct = set(versions.values())
        if len(distinct) > 1:
            fail(f"{name}: version drift across manifests -> {versions}")


def check_no_schema_key() -> None:
    # A $schema key makes Codex treat the package as an Agent Plugin and truncate each
    # SKILL.md at 8,000 bytes; omp routes to a strict provider that rejects most skills.
    for name, pkg in PACKAGES.items():
        for m in pkg["manifests"]:
            if m.exists() and "$schema" in json.loads(m.read_text()):
                fail(f"{name}: {m.relative_to(ROOT)} carries a $schema key")


def check_catalog_sources_resolve() -> None:
    for c in CATALOGS:
        if not c.exists():
            continue
        data = json.loads(c.read_text())
        for entry in data.get("plugins", []):
            src = entry.get("source")
            rel = None
            if isinstance(src, str):
                rel = src
            elif isinstance(src, dict):
                if "subdir" in src:
                    fail(f"{c.relative_to(ROOT)}: entry '{entry.get('name')}' uses 'subdir', "
                         f"which no catalog format defines — the supported key is 'path'")
                if src.get("type") == "local":
                    rel = src.get("path")
                elif "path" in src:
                    rel = src["path"]
            if rel is None:
                continue
            target = (ROOT / rel).resolve()
            if not target.is_dir():
                fail(f"{c.relative_to(ROOT)}: entry '{entry.get('name')}' source '{rel}' "
                     f"does not resolve to a directory")
                continue
            has_manifest = any((target / d / "plugin.json").exists()
                               for d in (".claude-plugin", ".grok-plugin")) \
                or (target / "plugin.json").exists()
            if not has_manifest:
                fail(f"{c.relative_to(ROOT)}: entry '{entry.get('name')}' source '{rel}' "
                     f"holds no plugin manifest")


def check_declared_skills_paths() -> None:
    for name, pkg in PACKAGES.items():
        for m in pkg["manifests"]:
            if not m.exists():
                continue
            declared = json.loads(m.read_text()).get("skills")
            if not declared:
                continue
            target = (m.parent.parent / declared.lstrip("./")).resolve()
            if not target.is_dir() or not any(target.glob("*/SKILL.md")):
                fail(f"{name}: {m.relative_to(ROOT)} declares skills '{declared}' "
                     f"which resolves to no non-empty skills tree")


def check_skills() -> None:
    seen: dict[str, str] = {}
    for name, pkg in PACKAGES.items():
        tree = pkg["skills"]
        if not tree.is_dir():
            fail(f"{name}: no skills tree at {tree.relative_to(ROOT)}")
            continue
        for d in sorted(tree.iterdir()):
            sk = d / "SKILL.md"
            if not sk.exists():
                fail(f"{name}: {d.relative_to(ROOT)} has no SKILL.md")
                continue
            fm = frontmatter(sk)
            if not re.search(r"^name:", fm, re.M):
                fail(f"{d.name}: frontmatter has no name")
            if not description_of(sk):
                fail(f"{d.name}: frontmatter has no description")
            if d.name in seen:
                fail(f"skill name collision: '{d.name}' in both {seen[d.name]} and {name} — "
                     f"neither harness merges same-named skills")
            seen[d.name] = name


def check_banned_constructs() -> None:
    # Each of these resolves only on Claude Code and fails SILENTLY elsewhere.
    banned = [
        (re.compile(r"\$ARGUMENTS"),
         "$ARGUMENTS is substituted in a SKILL.md body only on Claude Code"),
        (re.compile(r"\$\{?CLAUDE_(SKILL_DIR|PLUGIN_ROOT)\}?"),
         "a Claude-Code-only path variable"),
    ]
    for pkg in PACKAGES.values():
        tree = pkg["skills"]
        if not tree.is_dir():
            continue
        for f in tree.rglob("*.md"):
            text = f.read_text(errors="replace")
            for pat, why in banned:
                for m in pat.finditer(text):
                    line = text[: m.start()].count("\n") + 1
                    # An explanatory mention naming the hazard is allowed.
                    ctx = text.splitlines()[line - 1]
                    if "only by Claude Code" in ctx or "only on Claude Code" in ctx:
                        continue
                    fail(f"{f.relative_to(ROOT)}:{line}: {why}")


def check_extension_points() -> None:
    contract = ROOT / "docs" / "extension-points.md"
    if not contract.exists():
        notes.append("no extension-point contract found; skipping key checks")
        return
    keys = re.findall(r"^\| `(\w+)` \|", contract.read_text(), re.M)
    writer = (ROOT / "skills" / "bootstrap-project" / "SKILL.md")
    writer_text = writer.read_text() if writer.exists() else ""
    readers = "".join(p.read_text() for p in (ROOT / "skills").rglob("SKILL.md")
                      if p.parent.name != "bootstrap-project")
    for k in keys:
        if f"`{k}`" not in writer_text:
            fail(f"extension point '{k}' is declared but bootstrap-project never writes it")
        if k not in readers:
            fail(f"extension point '{k}' is declared but no core skill reads it")


def check_guides() -> None:
    """Public setup guides must not carry a real identifier or an unquoted --format.

    The guides are written by running every command against a live account, so a real
    org, project, or billing id can reach a public repository by copy-paste. And an
    unquoted --format=value(...) fails in both zsh and bash, which is exactly the
    paste-time breakage the guides exist to prevent.
    """
    guides = ROOT / "docs" / "guides"
    if not guides.is_dir():
        notes.append("no docs/guides/ directory; skipping guide checks")
        return
    leak = re.compile(
        r"blueprint-data-warehouse|jay\.graves|\bjaybna\b|gho_[A-Za-z0-9]|"
        r"\b[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}\b",
        re.I)
    for f in sorted(guides.rglob("*.md")):
        text = f.read_text(errors="replace")
        for i, line in enumerate(text.splitlines(), 1):
            if leak.search(line):
                fail(f"{f.relative_to(ROOT)}:{i}: a real account, project, or billing "
                     f"identifier appears in a public guide")
            # An unquoted --format=value(...) breaks on paste in zsh and bash. Lines that
            # are demonstrating the broken form say so.
            if re.search(r"--format=[^'\"`\s]", line) and "fails in both" not in line \
                    and "works;" not in line and "works." not in line:
                fail(f"{f.relative_to(ROOT)}:{i}: unquoted --format argument — "
                     f"it fails on paste in zsh and bash")


def check_budget() -> None:
    for name, pkg in PACKAGES.items():
        tree = pkg["skills"]
        if not tree.is_dir():
            continue
        total = sum(len(description_of(f)) for f in tree.rglob("SKILL.md"))
        limit = BUDGETS[name]
        pct = total / limit * 100
        notes.append(f"{name}: {total} description bytes ({pct:.0f}% of the {limit} budget)")
        if total > limit:
            fail(f"{name}: description budget exceeded — {total} bytes against a {limit} "
                 f"limit. These load into every session in every project.")


def main() -> int:
    budget_only = "--budget-only" in sys.argv
    checks = [check_budget] if budget_only else [
        check_manifests_parse, check_version_parity, check_no_schema_key,
        check_catalog_sources_resolve, check_declared_skills_paths,
        check_skills, check_banned_constructs, check_extension_points,
        check_guides, check_budget,
    ]
    for c in checks:
        try:
            c()
        except Exception as e:  # a crashing check is a failing check
            fail(f"{c.__name__} crashed: {e}")

    for n in notes:
        print(f"  note: {n}")
    if failures:
        print(f"\nFAIL — {len(failures)} problem(s):")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"\nOK — {len(checks)} check group(s) passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
