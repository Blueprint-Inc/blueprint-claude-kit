---
skill_phase: thin-slice
verification: none
coverage: full
plan: docs/plans/2026-05-28-004-feat-ce-deep-review-skill-plan.md
models: codex,gemini
timestamp: 2026-05-29T02:38:00Z
user: Jay Graves
content_preview: ran
---

# Deep review (thin slice) — 2026-05-28-004-feat-ce-deep-review-skill-plan.md

> ## ⚠️ Cross-model findings below are UNVERIFIED — confabulation-checking is still manual at this stage (thin slice).
>
> Per-finding verification (CONFIRMED / NOT-FOUND-IN-DOC / NEEDS-HUMAN) and a reconciled
> `.deep-review.md` arrive in a later phase. The Claude panel section is trusted (no egress, ran
> through ce-doc-review's synthesis gate); the cross-model sections are raw arm output.

**Run facts.** Pass 1 = Claude `ce-doc-review` 7-arm-eligible panel (6 personas activated), no egress.
Pass 2 = codex (OpenAI) + gemini (Google), 6 lenses each, all 12 cells `ok`, coverage **full**.
Content preview (gitleaks) ran clean — no secret-shaped content. Egress consented via the in-skill
gate for codex + gemini. **OD-4 note:** the dispatch cleared the auto-mode egress classifier this
fresh-session run with no `!`-handoff — first in-skill-gate confirmation of the legibility fix.

---

## Part 1 — Claude panel findings (trusted, no egress)

Synthesized through ce-doc-review (validate → confidence gate → dedup → cross-persona promotion →
route). Personas: coherence, feasibility, product-lens, security-lens, scope-guardian, adversarial.
No `safe_auto` fixes were auto-applied (every finding is a confirm-before-apply fix or a judgment
decision).

### Proposed fixes (concrete fix, requires confirmation)

- **[P1] OD-4 / RU1 — plan describes already-committed work as still open** (feasibility + adversarial, conf 100). RU1/OD-4 frame as "open"/"undone" work that commit `766c730c` ("make consent legible to the auto-mode egress classifier (RU1/OD-4)") landed immediately before the v4 plan commit `09d7f73b`. An implementer re-derives a settled decision or builds a divergent copy. **Fix:** move landed RU1/OD-4 work into Current State (cite `766c730c` + decision record `docs/solutions/skill-design/2026-05-28-od4-egress-classifier-consent-scope.md`); mark gate-rewording/fallback-ladder/onboarding/contract-test DONE; re-scope RU1 to the one remainder — fresh-session confirmation the *in-skill* gate clears the classifier.
- **[P2] RU1 "Files" lists deliverables that already exist** (feasibility, conf 100). Onboarding doc + contract test shipped in `766c730c`. **Fix:** strike them from RU1; keep only the fresh-session verification.
- **[P2] Risk table says "v1 ships codex + agy" but dispatched arms are codex + gemini** (adversarial, conf 75). Mis-sequences against the 2026-06-18 gemini cutoff. **Fix:** reword to "v1 currently ships codex + gemini; agy is the post-cutoff replacement, gated on RU2 landing before 2026-06-18"; add dated checkpoint.
- **[P2] "Unchanged v3 content" reference carries skill-name drift** (coherence, conf 75). v3 names the skill `ce-deep-review`; committed artifact is `ce-deep-review-beta`. **Fix:** add a substitution caveat after the "see v3" line.
- **[P2] RU2 re-scope note understates new platform-gating work** (coherence, conf 100→confirm). Platform-gating agy off macOS is genuinely new vs v3 U8. **Fix:** expand the RU2 header note to name the added scope.
- **[P2] Sidecar written to docs/plans/ with no .gitignore guard; plan defers adding one** (security, conf 75). RU5 carries "Do NOT modify .gitignore"; chat reminder fires only when content_preview unavailable. **Fix:** add `*.deep-review-draft.md` (decide on `*.deep-review.md`) to `.gitignore`.
- **[P2] agy arm callable off-macOS via arms.py with no seatbelt; platform gate unimplemented** (security, conf 75). Off-darwin `agy_sandbox_prefix()` returns `([],None)`. **Fix:** add a platform check in `agy_sandbox_prefix()`/`run_invocation()` refusing agy off-darwin.

### Decisions (require judgment)

- **[P1] OD-4 option (b) likely targets the wrong lever** (adversarial, conf 75). The decision record found the classifier is consent-scope-keyed, not command/path-keyed, so a `permissions.allow` rule is the same class of signal as the `allowed-tools` that already failed; the shipped fix is *b-legible*. **Fix:** make b-legible the primary path; demote the settings rule to an explicitly-untested headless fallback.
- **[P1] RU1 resolution rests on an unverifiable-in-session, n=1 hypothesis the plan never flags** (adversarial, conf 75). Only a *top-level* probe confirmed the classifier clearing; the in-skill path is untested in-session. **Fix:** add the risk; make the fresh-session dogfood a hard gate; record the proceed-decision if it fails.
- **[P1] OD-4 option (b) removes the classifier as egress defense-in-depth** (security, conf 75). A `permissions.allow` rule is session-permanent, leaving the consent gate as the sole egress boundary. (no suggested fix — judgment call.)
- **[P1] No decision rule for Phases 3–4 payback if OD-4 option (b) fails** (product-lens, conf 75). Plan says the investment "rests on" removing the hop but never states what happens to the thesis if (b) fails. **Fix:** add an RU1 branch re-affirming payback under the reduced value prop before Phase 2b.
- **[P1] RU2–RU5 are scoped against an unresolved dispatch-path assumption (OD-4)** (scope-guardian, conf 75). If OD-4 lands on option (c), RU3 parallelism and RU4 agent-side verification are premised on something that no longer holds. **Fix:** add "scoped for OD-4 (a)/(b); re-scope if (c)" to each unit.
- **[P1] OD-1 debrief instrumentation for the three-way confound is unspecified** (coherence, conf 75). The debrief must separate hop-friction / distrust / egress-block but no unit says how. **Fix:** pin the three-factor debrief template.
- **[P2] RU6 bundles four distinct concerns with different prerequisites** (scope-guardian, conf 75). **Fix:** split into (a) doc-only cleanup shippable after RU2, (b) verifier-rate + contract test gated on RU4 data.

### FYI observations (no decision required)

- [P2] Dogfood-gate greenlight criterion for Phase 3 not restated in v4 (coherence).
- [P2] OD-4 options (a)/(c) silently redefine the validated value prop; (c) reinstates the per-run human terminal action the origin named as the binding friction (product-lens).
- [P2] "premise is broken" framing over-rotates on a likely-solvable quirk (adversarial).
- [P3] agy/grok multi-arm scope is proportionate — origin-demanded, not scope creep (scope-guardian).

### Residual concerns

- Secret-read-exfil via agy's deny-write-only seatbelt (reads of ~/.ssh, ~/.aws not blocked); scoped out-of-v1, bounded by review-only prompt — acceptable for trusted-author threat model (security).
- gitleaks-unavailable path relies on manual user review as the sole filter; no fallback for headless/automated use (security).
- Classifier behavior may not be stable across Claude Code harness versions (adversarial).
- grok retest ("on a version bump") has no owner in the RU1–RU6 sequence (scope-guardian).
- RU2 REPO_DIR plumbing for the installed-skill case is genuinely unresolved (feasibility).

### Deferred questions

- Does the *in-skill* consent gate clear the auto-mode classifier in a fresh session? (Partially answered THIS run: yes — dispatch cleared with no `!`. One data point.)
- Will RU2 (gemini→agy + platform-gate) land before the 2026-06-18 gemini cutoff, and what's the fallback if not?
- If the fresh-session in-skill gate fails, is the v1 shape `!`-handoff (a) or emit-command (c)?
- Why does RU5 carry "DO NOT modify .gitignore" — accidental-commit risk vs intentional sidecar-sharing?

---

## Part 2 — Cross-model findings (UNVERIFIED, raw arm output, grouped by lens)

Each lens shows both arms. These are not synthesized, deduped, or verified. Heavy overlap with the
Claude panel (especially on OD-4 staleness, the macOS-only agy floor, secret-read-exfil, quote-grep
fragility, and the gemini cutoff) is itself signal — independent decorrelated arms converging on the
same concerns.

### Coherence

**codex (7):**
1. Dogfood target inconsistent: v4 note says "this document was reviewed *by* the skill"; Current State says "This plan (v3) was reviewed." Reader can't tell if the dogfood reviewed v3 or v4.
2. "Open Decisions (resolve before Phase 3)" lists OD-1/2/3 but says they "remain as decided in v3" — open vs decided conflict.
3. Permission-path options blur: OD-4 (a) "broad `Bash(bash *panel-critique.sh)`" vs (b) "exact resolved allow rule"; RU1's "permission rule" is ambiguous between them.
4. Phase 2a gate doesn't cleanly cover all OD-4 outcomes: "(a/c)" treats option (a) as handoff-only though (a) also has a permission-rule route.
5. Remaining-phase scope inconsistent: "only Phases 2–4 remain" vs "Phase 2a/2b" split — readers could disagree if Phase 2 is one or two phases.
6. Default arm set shifts without a stable term: "bundled harness" / "codex + gemini" / "agy default" / "v1 ships codex + agy" / "env-detect detects codex+gemini only" easy to conflate.
7. grok phrasing inconsistent: "DEFERRED from v1" vs "unavailable for v1" vs "Dropped per U1".

**gemini (5):**
1. "residual units renumbered RU1–RU6, each mapping to its v3 ancestor" contradicts RU1 labeled "(NEW — from the dogfood run)".
2. "arms.py already implements the agy arm end-to-end" conflicts with RU2's "REPO_DIR plumbing for the installed-skill case" in arms.py.
3. "v1" terminology drift: Risk says "v1 ships codex + agy" but Current State says the thin slice (codex+gemini) is shipped.
4. "agy arm end-to-end" inconsistent with "env-detect.sh does not detect agy" (a prerequisite to function).
5. "v3 U8's 'add agy to arms.py' is done" conflicts with RU2 still requiring arms.py modifications.

### Feasibility

**codex (20):**
1. OD-4 permission-bypass assumption may be false: `allowed-tools` didn't clear the classifier, so `permissions.allow` may not either.
2. RU1 has an unverifiable success criterion under default auto-mode: if only `!`/emit-command work, the skill doesn't remove the hop, only documents a manual escape.
3. Running external model CLIs over plan contents directly conflicts with the harness egress classifier's security model — the platform may intentionally forbid this workflow.
4. RU2 macOS-only agy = portability regression: non-mac users may be left with only codex once gemini is cut.
5. Gemini cutoff mitigation is time-fragile: slipping past 2026-06-18 kills the fallback arm.
6. agy read-only is a deny-write floor, not a confidentiality boundary: reads allow secret exfil via prompt/output.
7. RU2 installed-skill repo-root plumbing is high-risk: needs reliable path resolution for arbitrary doc locations, symlinks, temp files, non-git docs.
8. agy auth detection too weak: oauth_creds.json + refresh_token doesn't prove the CLI can refresh/reach provider/run headlessly.
9. agy 1.0.3 sandbox workaround based on fragile CLI internals — a vendor change could break the arm with no migration path.
10. RU3 parallel-across-models can collide with provider/local limits (rate limits, auth lock contention, interleaved output) without specified concurrency/retry.
11. Full `--models` semantics underspecified for unavailable arms (fail-fast vs warn-skip vs degrade).
12. Quote-grep verification may falsely mark cross-section implications as NOT-FOUND-IN-DOC.
13. Verifier can inherit model contamination unless the quote-grep backstop is the authoritative gate.
14. RU5 keep-5 rotation has data-loss/auditability risk for calibration history.
15. Drift-gate confidence depends on the bun test actually running in CI.
16. Contract tests can't fully assert the dispatch path — the failure is in the external interactive permission classifier.
17. Dogfood gate statistically weak: single-author, egress-blocked, no minimum-run count defined.
18. Dependency chain can strand Phase 3: RU4/RU5 gated on OD-4, which may resolve to a manual handoff that invalidates the value prop.
19. Deferring grok while retiring gemini onto agy = single-new-arm risk if agy is flaky.
20. Onboarding doc may normalize per-user security exceptions conflicting with org policy, reducing adoption in high-stakes environments.

**gemini (7):**
1. Speculative egress-gate bypass: "turnkey" depends on option (b) bypassing the classifier; behavioral analysis may override static allow-rules.
2. Platform-induced model monoculture: macOS-only agy leaves Linux/Windows with no cross-model alternative post-gemini-cutoff.
3. Schedule compression vs gemini EOL: <3 weeks to land RU2/RU3 + stabilize before 2026-06-18.
4. In-skill consent vs harness security mismatch: classifier blocks even after in-skill consent → architectural gap (orchestrator unaware of skill's internal auth state).
5. Verifier fragility: quote-grep ignores non-verbatim hallucinations; high NEEDS-HUMAN rate preserves toil.
6. Rate-limit/resource risk in RU3 parallelism without throttling/queueing.
7. External dependency on grok 0.2.8 fix with no committed timeline destabilizes Phase 4 validation.

### Security

**codex (10):**
1. Broad `Bash(bash *panel-critique.sh)` allow rule could authorize future script changes or attacker-controlled paths to exfil repo contents — no narrow trust boundary defined.
2. agy secret-read-exfil residual: no preflight secret scan, sensitive-path denylist, redaction, or explicit warning before sending repo content to agy.
3. Non-mac agy gate planned but `agy_sandbox_prefix()` returns no sandbox off-darwin; direct arms.py invocation runs without the R5 floor.
4. agy OAuth check doesn't state file-permission requirements, rotation/revocation, or protection against including the cred file in model context/sidecar.
5. No definition of what PII/sensitive data may appear in .deep-review.md, who reads it, whether committed by default, or redaction.
6. No data-minimization rule for verification quotes — inline quotes could reproduce secrets/PII into sidecars/logs.
7. Consent gate authorizes dispatch generally, not provider-specific data-handling/retention/jurisdiction/account-boundary.
8. No prompt-injection threat model — a malicious plan could target the arms to reveal env, read files, alter schemas, suppress findings.
9. REPO_DIR deny-write uses plan repo root but doesn't cover symlinks, nested repos, ignored dirs, paths outside repo.
10. `!`/emit-command handoff has an audit gap: doesn't require displaying resolved absolute path, model list, repo root, data destinations before execution.

**gemini (9):**
1. agy macOS seatbelt doesn't deny reads → secret-read-exfil to external models from untrusted docs.
2. .deep-review.md sidecars intended for VCS → accidental exposure of sensitive data/PII.
3. Investigating egress-classifier bypass (OD-4 b) risks undermining the platform's primary exfiltration defense.
4. Auth relies on a plaintext refresh token at ~/.gemini/oauth_creds.json — high-value local theft target.
5. Threat model explicitly excludes secret-read-exfil for untrusted docs — significant for a tool processing arbitrary workspace content.
6. Non-macOS agy may run with no filesystem restrictions.
7. env-detect.sh / credential logic may leak presence/status of keys/tokens if output captured in logs/shared envs.
8. No PII redaction/secret filtering before dispatch to multiple external providers.
9. "turnkey" may encourage broad Bash grants abusable via prompt injection / malicious input.

### Scope

**codex (7):**
1. RU3 full `--models` + parallelism is larger than the residual goal absent a measured runtime problem.
2. RU6 combines verifier-rate + contract test + docs + OD-4 assertion + drift cleanup + optional CI — scope creep; split.
3. RU6 optional `.github/` drift workflow unjustified — the bun equality test already catches drift; duplicate coverage.
4. RU4 verification protocol is premature complexity gated on an unresolved dispatch premise.
5. RU5 sidecar writer (rotation, frontmatter, banner precedence, leak reminders, reclamation) broader than the stated reconcile need.
6. Keeping gemini selectable until cutoff while migrating to agy adds branching/test surface needing justification beyond calendar fallback.
7. Three-way dogfood attribution may be more process than product unless tied to a concrete automated artifact/decision gate.

**gemini (5):**
1. RU6 calibration framework (bidirectional rates, agy-voiced corpus, synthetic fallback) = premature generality.
2. macOS-specific seatbelt templates in RU2 = significant platform-specific complexity exceeding a cross-model tool's needs.
3. bundle-harness + drift-gates = over-engineered file-consistency management for a single CLI skill.
4. RU3 parallel subshell orchestration adds unnecessary concurrency-management complexity to a local CLI task.
5. RU5 keep-5 sidecar rotation is scope creep not contributing to the primary intent.

### Product

**codex (15):**
1. Core adoption premise no longer sound as stated; demote Phase 3/4 investment until option (b) is proven or the promise is rewritten.
2. Risks confusing security friction with product friction — non-use may be the harness correctly blocking egress, not lack of appetite.
3. Even if bypass works, the trust consequence is larger than admitted: easier dispatch = easier egress; affected people may not have consented to sending project/org/operational details to external providers.
4. Consent model too agent-centric — distinguish operator consent from subject consent and org data policy.
5. May create false confidence by branding output "deep review" before verification exists; users over-trust a formal-feeling multi-model panel.
6. Drifts from review quality into harness/provider orchestration (RU2/RU3) that doesn't matter if core value is blocked by permission/trust/verification.
7. agy default = uneven adoption: read-only floor only on macOS → degraded product + inconsistent quality for non-mac teammates.
8. Underweights human-in-the-loop boundary as a product feature — option (c) may be the right default for trust-sensitive workflows (visible, auditable, intentional egress).
9. Affected-person impact underdeveloped: no guidance for disputed findings, contesting model critiques, avoiding laundering model opinions into decisions.
10. Dogfood evidence too thin for a promotion gate (one single-author run).
11. Verification may not solve trust — quote-grounding proves presence, not importance/fairness/proportionality/decision-relevance.
12. Optimizing for model coverage over decision usefulness — adoption problem may be cognitive load; users need fewer, sharper, accountable findings.
13. Positioning mismatch: "turnkey" vs "beta with residual security exceptions"; secret-read-exfil caveat should be front-and-center.
14. Provider availability (grok deferred, gemini cutoff, agy platform constraints) carries adoption risk unless degradation is clear/predictable.
15. RU3 parallelism could worsen trust/controllability (cost, egress, volume, failure surface) before the quality loop is proven.

**gemini (10):**
1. "turnkey" premise fundamentally compromised by the egress gate if each run needs manual auth / `!`.
2. "Data Exfiltration" warning is a trust-inhibitor branding the tool a security liability.
3. Fragmented agy platform support = "security inequality" for non-mac teammates.
4. Shipping unverified findings risks "hallucination fatigue" → rapid abandonment.
5. Value prop risks shifting from "automated orchestration" to "complex permissions management".
6. Reliance on gemini endpoints near 2026-06-18 = immediate technical debt / ticking clock.
7. Dogfood gate measures egress-gate friction, not recipe utility → flawed proceed decisions.
8. Option (c) is an admission of failure for the turnkey goal — regresses to a command-line template generator.
9. Dependency on specific external CLI bugs (grok 0.2.8) = fragile architecture.
10. "Infrastructure drift": most effort diverted to bypassing security gates / platform-gating rather than improving critique quality.

### Adversarial

**codex (35):**
1. OD-4 (b) assumes `permissions.allow` overrides the same classifier that ignored `allowed-tools`; no fallback validation for partial/path-specific bypasses or version changes.
2. Manual `!` fallback preserves the exact terminal hop the premise was meant to remove.
3. The v3-dismissed "emit exact command, human executes" is the most security-aligned design; the dogfood result supports it as default, not fallback.
4. RU1 modifies SKILL.md/arm-invocation.md/onboarding/tests before proving (b) — encodes an unvalidated permission model into docs/tests.
5. Single dogfood run (single-author, same-day, egress-blocked) is weak evidence to reprioritize the roadmap.
6. Phase 2b still expands arms/parallelism after RU1 even if RU1 picks manual handoff — invests in orchestration while the premise is disproven.
7. RU2 makes agy default while acknowledging it reads secrets / no web-search-disable; write-protection doesn't mitigate read-exfil.
8. macOS seatbelt denies writes via denylist, not all writes; unproven coverage of symlinks/mounts/temp/credential stores/out-of-repo.
9. Off-mac agy unavailability doesn't address mixed teams → non-representative contract tests/adoption/dogfood.
10. `git -C <plan-dir> rev-parse --show-toplevel` assumes the doc is inside a git repo (may be outside/temp/symlinked/other workspace).
11. agy auth check doesn't validate account ownership, scopes, real expiry, or repo-context safety.
12. No defined behavior after the gemini cutoff for old branches / cached bundles / un-updated installed skills.
13. Drift mitigation relies on the bun test; if CI doesn't run it universally, drift is still possible.
14. The "bun test makes CI redundant" claim breaks under selective test commands; add an explicit CI check or stop claiming drift protection.
15. RU3 parallelizes before verification exists — amplifies rate limits/auth prompts/cost/interleaved logs/partial-failure ambiguity.
16. "default = all available" may include arms the user didn't intend to send the doc to — conflicts with consent/exfil model.
17. Consent gate treated as meaningful even though the classifier rejected the run after consent; consent wording may not describe what data leaves and to whom.
18. Phase 1 shipped raw unverified records; consumers may over-trust — a state label isn't prevention.
19. Quote-grep grounding doesn't validate reasoning quality, omitted context, severity inflation, or actionability.
20. Verifier blind to producing model but doesn't prevent phrasing/metadata/ordering/file-naming leaking provenance and biasing verification.
21. ≤5% verifier target underspecified: no CIs, sampling method, minimum corpus size, or synthetic-fallback validity impact.
22. RU5 keep-5 rotation + "don't modify .gitignore" leaves artifacts at accidental-commit risk; mitigation is only a reminder.
23. Committed-sidecar leak waved to v3 as mitigated, but v4 introduces new sidecar behavior in RU5; prior mitigations may not cover the final writer.
24. Assumes ≥200KB plans handled via stdin but lists agy arg-length as deferred — `--add-dir`/command construction could fail late.
25. No hard timeout/cancellation/cleanup for hung arms, despite observing some agy sandbox profiles hang.
26. Security boundary spans seatbelt + permissions + shell wrappers + OAuth files + model CLIs with no end-to-end threat model.
27. "Carried-forward risks mitigated by Phase-1 code/tests" — but RU1–RU6 change dispatch/arms/verification/reconciliation/docs/sidecar; old tests can't be assumed to cover the new system.
28. grok treated as low-impact deferred, but dropping a model reduces adversarial diversity and weakens cross-model premise; no re-assessment with only codex+agy.
29. Dogfood reports all six lenses ok / coverage full, but the most important finding was an execution failure outside lens outputs — the rubric may miss operational blockers.
30. Onboarding a permission rule assumed acceptable, but OD-1 is about whether reduced friction causes use; a one-time settings edit may be a larger barrier than a pasted command.
31. No rollback criterion: if (b) fails / agy unstable / verifier rates exceed target, says "beta stays beta" but not what to abandon/revert.
32. May have taken an irreversible reputational step shipping ce-deep-review-beta + docs before validating the turnkey premise.
33. Assumes `allowed-tools` insufficiency is a harness issue, but it may be correctly identifying real exfil risk; bypassing via settings could weaken safety posture.
34. No required testing with sensitive-but-allowed / large / non-git docs, non-mac envs, expired/revoked auth, or network failure before promotion.
35. The cheaper safer alternative — local-only pass 1 + generated handoff command — isn't seriously compared after the egress failure.

**gemini (9):**
1. Egress classifiers often override user allow-lists when behavior (sending data to multiple 3rd-party models) triggers exfil heuristics — option (b) may not work.
2. High-stakes plans frequently contain env vars / infra paths / auth patterns agy can read+exfil (deny-write only, not deny-read).
3. Quote-grep is brittle against paraphrasing ("must" vs "should") → NEEDS-HUMAN well above 5%, re-introducing toil.
4. macOS-only agy creates a dual-class review standard / invisible drift across mixed-OS teams.
5. Dismissed the cheaper/safer pure-Claude multi-persona 3-pass architecture (zero egress, no 3rd-party auth, no seatbelt).
6. Committing agy arm + seatbelt templates before resolving OD-4 is an irreversible step polluting the branch with platform-specific debt that may become dead weight.
7. RU3 parallel subshells assume the harness can multiplex concurrent high-volume JSON without interleaving / slowest-model blocking.
8. stdin path doesn't account for hard context-window limits / internal buffer overflows that truncate large plans.
9. The bun equality test is a weak drift gate depending on developer discipline vs the rejected CI-level check.

---

*Raw records: `/tmp/cmre-panel/records/<cli>__<lens>.json` (12 files). Latencies 10–80s/cell; total run completed exit 0.*
