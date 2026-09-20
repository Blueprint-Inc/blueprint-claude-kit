#!/usr/bin/env python3
"""PreToolUse scope gate. Fail-open. Never grants. No secrets on stderr."""
import json
import os
import re
import sys
import urllib.error
import urllib.request


def allow():
    print(json.dumps({"decision": "allow"}))
    sys.exit(0)


def deny(reason):
    print(json.dumps({"decision": "deny", "reason": reason}))
    sys.exit(0)


UNGATED = {
    "read_file",
    "grep",
    "list_dir",
    "search_tool",
    "web_search",
    "web_fetch",
    "todo_write",
    "Read",
    "Grep",
    "Glob",
}

# Only these tool-input fields are ever sent. Everything else stays local: file
# contents and diffs carry the most secret material and add nothing the judgment
# needs, which is the path and the command.
SENT_FIELDS = ("command", "path", "file_path", "target_file", "url")
MAX_FIELD = 600

# Redact secret-shaped literals before egress. These strip values, never paths --
# `cat ~/.aws/credentials` must still read as reaching for credentials, because
# that is exactly the signal the gate is asking about.
SECRET_PATTERNS = (
    re.compile(r"\b(sk|pk|rk)-[A-Za-z0-9_-]{16,}"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{16,}"),
    re.compile(r"\bAKIA[0-9A-Z]{12,}"),
    re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    re.compile(r"(?i)\b(bearer|token|secret|password|passwd|api[_-]?key)"
               r"(\s*[:=]\s*|\s+)(\"|')?[A-Za-z0-9_\-\.\/\+]{8,}"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
    re.compile(r"\b[A-Fa-f0-9]{40,}\b"),
)


def scrub(value):
    text = str(value)
    for pattern in SECRET_PATTERNS:
        text = pattern.sub("[redacted]", text)
    if len(text) > MAX_FIELD:
        text = text[:MAX_FIELD] + "...[truncated]"
    return text


try:
    event = json.loads(sys.stdin.read() or "{}")
except Exception:
    allow()

tool = str(event.get("toolName") or event.get("tool_name") or "")
if tool in UNGATED:
    allow()

home = os.environ.get("GROK_HOME") or os.path.expanduser("~/.grok-thin")
catalog_path = os.path.join(home, "state", "thin-catalog.json")
try:
    with open(catalog_path) as fh:
        catalog = json.load(fh)
    remaining = [str(n) for n in catalog.get("names") or []]
except Exception:
    allow()

if not remaining:
    allow()

if tool and tool not in remaining:
    deny("Thin session: tool is outside the remaining closed set.")

key_path = os.environ.get("JEV_API_KEY_FILE") or os.path.expanduser(
    "~/.config/dev-approved-lfg/jev_api_key"
)
if not os.path.isfile(key_path):
    allow()
try:
    with open(key_path) as fh:
        key = fh.read().strip()
except Exception:
    allow()
if not key:
    allow()

tool_input = event.get("toolInput") or event.get("tool_input") or {}
if not isinstance(tool_input, dict):
    tool_input = {}
state = {"tool": tool, "cwd": scrub(event.get("cwd") or os.getcwd())}
for field in SENT_FIELDS:
    if tool_input.get(field):
        state[field] = scrub(tool_input[field])

# Nothing to judge beyond the tool name, and a bare name carries no signal: the
# model answers from the name alone and denies the same tools every session.
# Fail open rather than gate on that.
if len(state) < 3:
    allow()

# /v1/systemone, no hyphen: the hyphenated path 404s, and because every failure
# here fails open, that 404 silently disabled the gate on every call. Pinned model
# rather than an alias: the confidence floor below is only meaningful against a
# fixed version.
endpoint = os.environ.get(
    "TYPESAFE_DECISIONS_URL", "https://api.typesafe.ai/v1/systemone"
)
model = os.environ.get("JEV_MODEL", "jev-1.13.0")
try:
    floor = float(os.environ.get("JEV_CONFIDENCE_FLOOR", "0.7"))
except (TypeError, ValueError):
    floor = 0.7

# A scope question, not a routing one. The previous "which tool should run now?"
# returned a routing opinion that allowed a sudoers edit and an ssh-key upload,
# because it never asked whether the action was safe.
body = json.dumps(
    {
        "state": state,
        "model": model,
        "questions": {
            "scope": {
                "type": "choice",
                "instructions": (
                    "Does this tool call stay inside the project directory and "
                    "leave credentials and system configuration untouched?"
                ),
                "criteria": {
                    "in_scope": (
                        "Ordinary development work confined to the project directory."
                    ),
                    "out_of_scope": (
                        "Reads or writes credentials or secrets, changes system "
                        "configuration, sends data off the machine, or destroys "
                        "data outside the project."
                    ),
                },
            }
        },
    }
).encode("utf-8")
req = urllib.request.Request(
    endpoint,
    data=body,
    headers={"Content-Type": "application/json", "Authorization": "Bearer " + key},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=2.5) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except Exception:
    allow()

answer = ((data.get("answers") or {}).get("scope") or {})
choice = answer.get("choice")
try:
    conf = float(answer.get("confidence") or 0)
except (TypeError, ValueError):
    conf = 0.0
if choice == "out_of_scope" and conf >= floor:
    deny("Jev: reaches outside the project, its credentials, or system config.")
allow()
