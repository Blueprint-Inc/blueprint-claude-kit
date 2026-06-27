---
skill_phase: thin-slice
verification: none
coverage: full
plan: docs/plans/2026-05-28-003-feat-ce-deep-review-skill-plan.md
models: codex, gemini
timestamp: 2026-05-28T22:56:20Z
user: Jay Graves
content_preview: ran
---

# Deep review (thin slice) — 2026-05-28-003-feat-ce-deep-review-skill-plan

> **⚠️ Cross-model findings below are UNVERIFIED — confabulation-checking is still manual at this stage (thin slice).**
> gemini in particular confabulates plausible-but-fake findings; codex over-emits (90 raw findings on the adversarial lens alone). Nothing below has been grounded against the plan text. Per-finding verification (CONFIRMED / NOT-FOUND-IN-DOC / NEEDS-HUMAN) and a reconciled `<plan>.deep-review.md` arrive in a later phase. Treat this draft as raw input, not a verdict.

**Run summary:** Pass 1 (Claude `ce-doc-review` panel, no egress) + Pass 2 (codex + gemini, 6 lenses each, 12 cells, all `ok`). Content scan: gitleaks ran, 0 hits. Coverage: full.

Raw records retained at `/tmp/cmre-panel-deepreview/records/`.

---

## Pass 1 — Claude panel findings (trusted, untagged)

The Claude `ce-doc-review` multi-persona panel (coherence, feasibility, product-lens, design-lens, security-lens, scope-guardian, adversarial). Applied 0 fixes. These are the calibrated, anchor-gated panel findings — they are NOT subject to the UNVERIFIED banner above (the banner applies only to the cross-model section).

### Proposed fixes (concrete fix, requires confirmation)

- **[P1] Actors / Key Flows F1 — Skill invocation name contradicts operational notes** (coherence, 100). Actors (L78) and the F1 trigger (L89) tell users to invoke `ce-deep-review`, but the actual beta-window name is `ce-deep-review-beta` (U3 L195; operational note L457). *Fix:* use `ce-deep-review-beta` in Actors + F1 trigger for the beta window.
- **[P1] agy seatbelt allows reads → secret-read-exfil residual in the response channel** (security-lens, 75). The agy seatbelt is deny-write-only; a prompt-injection payload in plan content could have its output flow back through `parse_findings()` into records/sidecar. The pre-egress plan scan doesn't cover the returned findings. *Fix:* scan each arm's raw findings record for credential-shaped/high-entropy strings before parse/present; flag matches NEEDS-HUMAN; document in `arm-invocation.md`.
- **[P1] grok-smoke.sh inlines sentinel content into `grok -p` argv** (security-lens, 75). `prompt="...$(cat "$sentinel")"` passed to `grok -p "$prompt"` is the shell-interpolation pattern arms.py forbids; the validation gates grok promotion. *Fix:* pass via `--prompt-file`/temp file.
- **[P1] F4-zero re-prompt content not pinned canonical** (design-lens, 75). The zero-selected re-prompt is only paraphrased while the ack/notice are CANONICAL; implementers will produce a divergent second gate. *Fix:* pin the re-prompt structure + exact notice in `consent-gate.md`.
- **[P1] Pass-2 `CMRE_TIMEOUT` default + "approaching" threshold undefined** (design-lens, 75). The streaming format commits to "approaching timeout"/"TIMED OUT" lines keyed on CMRE_TIMEOUT with no value or threshold. *Fix:* pin a concrete default (e.g. 120s/cell) and define "approaching" (e.g. >80% elapsed) in `arm-invocation.md`.
- **[P2] Pass-1 timeout value + failure-vs-timeout boundary unspecified** (design-lens, 75). "define the timeout" is left open; timeout vs parse-failure undistinguished. *Fix:* specify value + detection condition in `pass-1-headless-envelope.md`.
- **[P2] Single-arm gate shape unspecified** (design-lens, 75). The one-available-model case has no spec. *Fix:* pin the single-model form (one toggle + Cancel, singular stem; or binary Send/Cancel) in `consent-gate.md`.
- **[P2] End-of-dispatch summary for mixed-outcome runs unspecified** (design-lens, 75). *Fix:* add an aggregate one-line summary format (full-ok / partial-timeout / all-timeout) to `arm-invocation.md`.
- **[P2] UNVERIFIED draft banner copy not pinned canonical** (design-lens, 75). *Fix:* move the banner into `reconciliation.md` as a CANONICAL block; reference from U5.
- **[P2] reduced-confidence coverage banner copy not specified** (design-lens, 75). *Fix:* add a canonical template with a named `[arm]` slot to `reconciliation.md`.
- **[P2] Committed-leak reminder timing relative to write is ambiguous** (design-lens, 75). *Fix:* specify a blocking Continue/Cancel before the sidecar write when `content_preview: unavailable`.
- **[P2] /tmp/cmre-panel/records/ has no access control or cleanup** (security-lens, 75). World-readable consented plan content; no permission/cleanup policy. *Fix:* `mktemp -d` at 0700 (or chmod 0700), add end-of-session cleanup, document CMRE_OUT_DIR override.
- **[P2] verifier-eval/ corpus placed under scripts/** (scope-guardian, 75). Co-locates a measurement harness with bundle-copy targets, muddies the self-contained-skill contract. *Fix:* move to a skill-root sibling (e.g. `eval/`).

### Decisions (require judgment)

- **[P1] Plan is stale relative to committed branch state** (feasibility, +5 related variants in FYI, 100). Phase 0 (U1/U2) and Phase 1 (U3–U6) already landed on this branch (006b7090; 6072ec54; e1226eda) but the plan presents them as forward-looking. Verified already-done instances: U2 agy auth discovered (OAuth at `~/.gemini/oauth_creds.json`, presence + non-empty `refresh_token` — "no offline signal → Option (c)" branch + calendar fallback are moot); U5 `--models` egress guard already exists in `panel-critique.sh`; U8 agy arm already implemented end-to-end in `arms.py`; U3 spec contradicts the committed `env-detect.sh` (detects codex+gemini, no grok/agy); grok already DEFERRED per the Phase-0 gate (0.2.8 relay-auth bug). *Fix:* add a "Current State" section reconciling done-vs-remaining and re-scope to the real residual (Phase 2+).
- **[P1] agy arm has no FS posture floor off macOS; plan never platform-gates** (security-lens + adversarial, +1 anchor → 100). `agy_sandbox_prefix()` returns `([], None)` on non-darwin, so R5's read-only invariant is silently violated for exactly the non-macOS teammates the skill targets, while `build_invocation` still labels sandbox "seatbelt-deny-write". *Fix:* treat agy as unavailable off macOS (env-detect platform-gates it; the gate must not offer it) until a Linux confinement mechanism lands.
- **[P1, chain root] Verification deferred behind the dogfood signal it would change** (product-lens, 75). Verification (the named most-error-prone, most-valuable step) lands in Phase 3, after the gate decides whether to keep building; the dogfood measures adoption of the *unverified* artifact while the actual value proposition is absent. *Fix:* move a minimal in-orchestrator inline grounding pass into Phase 1; keep the heavy verifier-rate work gated.
  - **[P1, dependent] Unverified probe to teammates may poison its own adoption signal + train distrust** (product-lens + adversarial, +1 anchor → 100). Phase 1 ships confabulation-prone unverified findings as the artifact whose adoption it measures; low re-use may reflect distrust of the probe, and the debrief attribution that should disambiguate is biased by that distrust. (Adding Phase-1 verification — the root's fix — dissolves this.)
- **[P1] Dogfood debrief samples only self-selected engagers** (product-lens, 75). The gate's discriminator depends on non-reviewers volunteering *why* they skipped; silent skippers are invisible. *Fix:* define a minimum-attribution floor (below it → "signal insufficient — extend"); capture trust and friction on independent scales.
- **[P1] Phase 1 front-loads bundling + state machine + drift CI before the gate justifies them** (scope-guardian, 75). U5 ships infrastructure for a multi-arm system the gate may never authorize. *Fix:* keep only the `--models` guard + record parsing in Phase-1 U5; move bundle-harness/drift-test/CI/state-machine to Phase 2.
- **[P2] Dogfood baseline reconstructed from 4-week memory undermines falsifiability** (adversarial, 75). The denominator was never captured prospectively; a confabulated near-zero baseline makes "materially higher share" trivially passable. *Fix:* enumerate actual high-stakes plans from git/docs history as a named-plan denominator.
- **[P2] Migration window can present 5 gate options, breaking the 4-cap** (adversarial, 75). gemini + agy both auth-detectable off `~/.gemini/oauth_creds.json` → codex+gemini+agy+grok+Cancel = 5. *Fix:* make gemini and agy mutually exclusive — remove gemini from detection once agy is wired.
- **[P2] Gemini arm crosses 2026-06-18 cutoff with no provisional-signal decision rule** (scope-guardian, 75). "extend the window" has no bounded endpoint and no rule for when provisional authorizes a narrowed Phase 2. *Fix:* add max extension duration + the condition under which provisional authorizes a narrowed Phase 2/3.

### FYI observations (anchor 50)

- (feasibility, stale-plan variants) U2 agy auth already discovered; U5 `--models` guard already exists; U8 agy arm already in arms.py; U3 env-detect spec contradicts committed script; grok already deferred per Phase-0 gate.
- (coherence) Success metric (L429) uses promoted name `ce-deep-review` not `-beta` — likely intentional (post-promotion measurement).
- (product-lens) The 30-min onboarding metric measures the doc-follower, not the per-vendor account friction (paid plan, DPA, logins) that's the real barrier.
- (security-lens) env-detect non-leakage rests on impl correctness; add stderr capture/discard at call sites + assert no high-entropy in stderr.
- (scope-guardian) U6 README beta row but the plugin.json/marketplace.json registration needed for `release:validate` is unspecified.
- (adversarial) The 06-15 calendar fallback has 3 days slack and no branch for joint agy+grok failure beyond "reconsider shipping."

### Residual concerns (panel)

- Could not locate the bundle-drift CI workflow / test file — the "CI fails on working-tree change" guarantee is unconfirmed (feasibility).
- agy-readonly.sb.tmpl allows network egress + unrestricted reads → read files could be exfiltrated to any endpoint; the seatbelt is write-protection only (security-lens).
- The verifier-eval corpus will contain real agy/grok findings derived from internal plan content and is checked into the repo; sanitization unspecified (security-lens).
- No frontmatter field distinguishes a Phase-2 multi-arm *unverified* run from a Phase-1 thin-slice *unverified* run (design-lens).
- Gate offering grok before U7 lands passes an unrecognized `--models` token panel-critique.sh silently drops; add a test asserting gate-offered models == runnable arm set (adversarial).

### Deferred questions (panel)

- When gemini and agy are both detectable during the U8 migration window, which arm wins, and is gemini removed atomically? (adversarial)
- Does the OAuth auto-refresh network call on the first agy invocation count as a pre-consent live call under R9? (security-lens)
- Is the bundle-drift CI step actually wired and green today? (feasibility)

---

## Pass 2 — Cross-model findings (RAW, UNVERIFIED)

> Everything below is verbatim model output, ungrounded. Many items overlap the panel's findings (corroboration signal) or each other; codex over-emits and gemini confabulates. Read as leads, not facts.

### Lens: coherence

**codex (10):**
- Phase 1 output is described as raw unverified records, but Key Technical Decisions calls it a bash handoff rather than turnkey dispatch. Summary says the thin slice ships "pass 1 + consent gate + raw unverified records" and OD-2 says "the agent runs the cross-model arms turnkey", while Key Technical Decisions says "U3–U6 ship a runnable, egress-safe panel + consent gate + bash-handoff". Readers could diverge on whether Phase 1 invokes the harness or only hands off a command.
- The Phase 1 dogfood fallback conflicts on whether codex-only can be used before the Gemini cutoff. U6 says single-arm is "codex-only post-cutoff"; Phased Delivery says swap to codex-only if the window would cross the date. A window crossing 2026-06-18 could start before cutoff, so the trigger is ambiguous.
- The document alternates between "grok stays in the consent gate" (OD-3, Dependencies) and Phase 1 using only codex+gemini (Actors). Consistent only if "consent gate" means the eventual/full gate, but that qualifier isn't stated.
- The adoption metric runs `ce-deep-review-beta` after verification, but promotion happens after U12 clears; if U12 clears quickly after Phase 3, readers may disagree whether the ≥5 runs must happen before promotion.
- U11 says `skill_phase` persists in rotated thin-slice drafts, but thin-slice output is `.deep-review-draft.md` and rotation is of `.deep-review.md` → unclear how a thin-slice draft becomes a rotated `.deep-review.<ISO>.md`.
- Sidecar audit fields inconsistent between F5 ("content_preview: unavailable (gitleaks not installed)") and U11 ("content_preview: ran|unavailable"); readers could encode either the enum or the explanatory string.
- The model-count justification for the gate cap is ambiguous because the final design includes codex+agy+grok plus Cancel; "≤4 models" conflicts with the stated inclusion of Cancel.
- U5 says "Does NOT depend on Phase 2" but its Dependencies are U3, U4; wording can be misread as broader independence.
- The calendar fallback "ship without agy" still includes grok, which may not have passed Phase 0 if Phase 0 hasn't completed (Phase 0 includes U1 grok validation).
- "No producing artifact exists before Phase 3" conflicts with the thin-slice draft sidecar; intended meaning seems "no verified artifact".

**gemini (5):**
- Actors/Phased Delivery say Phase 1 uses codex+gemini, but U3's env-detect.sh detects codex/grok/agy while omitting gemini.
- "Alternative Approaches" says the thin-wrapper destination "only drops the grok arm", contradicting the Calendar fallback's "2-arm (codex + grok) config" if Antigravity is dropped.
- U3 Approach/Dependencies claim it implements "agy (the U2 rule)", contradicting U8 (replace the agy TODO stub) and the Phased Delivery note that Phase 1 ships an agy TODO stub.
- Phased Delivery says Phase 1 is "against the current codex+gemini harness", but U3 implements grok detection even though the grok arm isn't added until U7 (Phase 2).
- OD-3/Dependencies say grok retention is "confirmed acceptable", yet the Phase 0 gate still lists "grok fails → drop grok".

### Lens: feasibility

**codex (23):**
- Consent-gate implementability: assumes a single AskUserQuestion supports multiSelect + default-none + Cancel + long dynamic stem; if multi-select isn't supported the core egress-consent design breaks.
- Option-count conflict: 3 models + Cancel is exactly at the cap; any added option/model exceeds the assumed UI envelope.
- `disable-model-invocation: true` plus internal `Skill()`/subagent/shell/interactive-gate calls may conflict with skill execution semantics unless explicit invocation still permits nested tool use.
- Read-only/runtime write risk: writes sidecars, /tmp records, runs gitleaks, rotates files; runtime may be sandboxed read-only with no fallback defined.
- Bash permission gate `Bash(bash *panel-critique.sh)` may pass while the script still invokes external CLIs/Python broadly.
- CI that runs bundle-harness.sh and fails on tree changes isn't auto re-bundling; it creates red builds and couples eval-only edits to unrelated PRs.
- U5 modifies the canonical eval harness (`--models`) which can change behavior for existing eval workflows; "minimal" but no backward-compat proof.
- Gemini HTTP-410 cutoff can invalidate the thin-slice signal mid-window; codex-only fallback is provisional.
- Dogfood measurement depends on humans reliably identifying all high-stakes plans + skip reasons; without telemetry the gate is subjective.
- agy dependency: CLI surface, auth, offline signal, sandbox, arg-length all unknown; downstream corpus/metric/3-arm claims still assume agy.
- grok one-turn smoke test can't establish durable sandbox guarantees across versions/auth/plugins.
- Verifier is another LLM over the same plan; grep backstop only checks quote existence, not support.
- ≤5% on ≥20 items N=3 is statistically fragile; one error ≈ 5%; synthetic agy items let promotion proceed without real agy.
- Sidecar leak: scans only input plan, defers sidecar scan; reminder doesn't prevent accidental commit.
- gitleaks isn't a general PII/confidentiality scanner; gate language may overstate protection.
- Offline auth checks can report available even when tokens expired/revoked/misscoped; gate may offer arms that then fail.
- /tmp/cmre-panel/records/ can collide across concurrent runs/users; absence of a deselected-arm file isn't reliable proof of no egress if stale records exist.
- Per-model/lens progress + timeout + parallel subprocess mgmt from shell is brittle across macOS/Linux + CLI buffering.
- Large-plan handling: full content through prompts/subagents/gitleaks/CLIs; only agy's -p cap called out; token/arg/temp/context limits can break.
- Panel-only conflict: F3 writes `.panel-review.md`, F4 Cancel writes no sidecar; declining users may expect the durable artifact.
- Promotion/naming migration deferred; installed beta copies/docs may linger or conflict unless cutover cleanup is tested.
- Cross-platform: assumes bash/python3/bun/gitleaks/codex/grok/agy/git/Unix; 30-min onboarding is macOS/Homebrew-flavored; no Windows/Linux parity.
- Evidence-of-no-egress relies on local record inspection; proves only no record file, not that the CLI wasn't invoked or no network egress occurred.

**gemini (10):**
- Gemini CLI sunset (HTTP-410) timing: tight dependency; window slip can invalidate the signal or break the skill before Phase 2.
- Speculative agy auth discovery: if agy only supports live auth-status or keychains, R9 renders agy permanently unavailable.
- Verification toil fallback: ≤5% miss → NEEDS-HUMAN tags restore manual friction, invalidating the adoption metric.
- Thin-slice signal contamination: noisy unverified findings → users revert to panel-only → false-negative "stop" even if verification would have solved it.
- Credential leakage in env-detect testing: if CI logs shell traces (set -x), credentials could leak despite stdout/stderr silence.
- Sidecar pollution: refuses to modify .gitignore but produces up to 5 rotated sidecars → high risk of committing quoted plan content, esp. gitleaks-absent.
- ce-doc-review headless contract fragility: parsing five envelope sections is a fragile cross-skill dependency.
- Large-plan arg-length: -p may hit ARG_MAX/prompt caps; --add-dir bypass is unverified.
- Process forking/concurrency: U9 parallelism assumes concurrent CLI invocations don't collide on lockfiles/ports.
- Drift-test CI coupling: non-skill devs modifying the canonical harness get blocked by a red skill build.

### Lens: security

**codex (20):**
- Consent isn't bound to an immutable plan snapshot; plan could change between gitleaks preview/consent and dispatch → different content egressed than approved.
- gitleaks scans only the plan; pass-2 may give CLIs broader fs access (cwd, doc dir, bundled scripts, auth files, temp, CLI defaults).
- gitleaks is secret-focused, not a general PII/confidential/regulated classifier; clean scan ≠ safe to egress.
- Raw records under /tmp may contain plan content/secrets/PII; no permissions/retention/cleanup/collision-isolation specified.
- Sidecars quote plan content and are commit-ready; sidecar scanning deferred → data-exposure path into VCS/PRs.
- Gate doesn't show actual configured account/org/region/retention-mode; could egress through a personal/misconfigured vendor account.
- Auth detection via file/env/expiry can false-positive on stale/wrong-account/tenant creds; no post-consent identity confirmation before egress.
- `Bash(bash *panel-critique.sh)` may be too broad if another matching script is reachable or args injectable; require exact resolved paths + quoted args.
- Bundled scripts can drift from canonical security fixes until CI catches; no integrity/provenance/security review on bundled-script change.
- No ongoing regression gate for vendor CLI updates weakening sandbox/web-search/fs behavior post-validation.
- Prompt-injection from the reviewed plan can target the orchestrator or external CLIs; no explicit injection hardening beyond per-arm directives.
- Verification passes full plan + findings to subagents repeatedly; no data minimization (bounded excerpts / path lookup).
- Availability notes + sidecar metadata may expose installed CLIs, auth status, git username, timestamps, vendors; not classified/redacted.
- env-detect "no credential values" doesn't address indirect leakage via shell tracing, errors, JSON parse errors, debug logs, core dumps, child stderr.
- No-live-call-before-consent focuses on vendor CLIs; pass-1/gitleaks/helpers may still hit network unless constrained; threat model should state allowed network access.
- No audit record of exactly which bytes were sent to each vendor / which command version / which consent authorized it (content hashes + version metadata).
- No handling for symlinks/hardlinks/path traversal/plans outside the repo; a path could point to sensitive files.
- Concurrent runs sharing /tmp/cmre-panel/records/ could collide/mix/leak across sessions unless run-specific private dirs enforced.
- Vendor prompts review high-stakes internal plans; no data-classification allow/blocklist (customer data, incidents, credentials, export-controlled, legal/HR).
- Threat model doesn't cover malicious/compromised vendor CLIs executing locally with plan + fs/auth context; need sandboxing/version-pin/provenance.

**gemini (8):**
- Prompt-side enforcement of read/write constraints (agy) is unreliable; bypassable via prompt injection or model non-compliance.
- Reconciliation quotes CONFIRMED findings in `.deep-review.md`; a secret/PII finding may be persisted + committed without redaction.
- "Graceful degradation" without gitleaks removes a critical automated gate, shifting all responsibility to error-prone manual review.
- Plan excludes scanning generated sidecars for secrets/PII despite them being version-controlled and containing extracted content.
- Documenting exact credential storage locations (agy auth path) in shared docs increases discovery risk by unauthorized readers.
- U2 auth discovery may violate R9 if introspection commands (auth status) trigger network requests.
- Egressing internal content to multiple external vendors (Anthropic, xAI, Antigravity) increases exposure surface + multi-party dependency.
- gitleaks only on the plan doc doesn't mitigate a model arm accessing/exfiltrating other files or env vars in the execution context.

### Lens: scope

**codex (10):**
- Phase 1 includes a broad platform build (scaffold, headless integration, consent UI, gitleaks wrapper, env detection, harness bundling, drift CI, state-machine docs, dispatcher streaming, sidecar writing, README/docs, contract tests) larger than the probe needs — risks spending much of the eventual implementation before the gate can invalidate the premise.
- U5's build-time copy + CI drift system is disproportionate for a beta probe; a minimal wrapper calling the canonical harness or `arms.py run-arm` would avoid duplicated files + drift coupling until value is proven.
- grok validation + agy migration kept in scope even though the uncertainty is team-wide adoption, not model coverage (U1/U2/U7/U8/U9/U12 add posture/auth/migration/calibration work before evidence the surface is worth expanding).
- U12 verifier eval (held-out corpus, N=3, bidirectional thresholds, multi-voice rep, synthetic fallback, calibration scopes, promotion gates) is production-grade model-eval, not the smallest verification guard.
- The consent gate accumulated premature policy/UX machinery (gitleaks preview, canonical copy, escalated ack, F4-zero, audit fields, leak reminders, contract assertions); core requirement is per-model opt-in before egress.
- U11 sidecar lifecycle over-scoped (verified/draft/panel filenames, banner precedence, frontmatter enums, rotate-to-5, persisted skill_phase, audit headers, leak reminders); a single labeled report would suffice for the beta.
- Extensive documentation artifacts before value established (six reference files, onboarding/user docs, findings/solution docs, README rows, brainstorm corrections).
- U9 parallel-across-model is premature vs the explicitly rejected full parallelism and the friction problem.
- Success metrics + dogfood gate require baseline reconstruction, skip/defer tracking, debrief categorization, distinct-dev thresholds, arm-config caveats, multiple routing outcomes — heavyweight for a 1–2 week beta.
- Several dependencies declared effectively required despite being optional/unresolved (grok creds, paid Antigravity + DPA, agy offline auth, gitleaks, posture validations); MVP could be codex-only/current-harness-only.

**gemini (7):**
- OD-1 dogfood-gate measurement (baseline, falsifiable thresholds, debrief instrumentation) exceeds the needs of an initial probe.
- U12 verifier-rate harness (held-out corpus + bidirectional calibration) is research-scale vs a turnkey dev tool.
- U11 custom sidecar rotation (history-cap + ISO archiving) adds unjustified complexity for a beta.
- U5 multi-dimensional state machine (5+ dimensions) is larger than needed for a linear tool-call sequence.
- "metric maturity" via skill_phase frontmatter (U11) is premature generality before the value hypothesis clears.
- U9 parallelization for only three models adds complexity the plan itself labels "over-complex".
- U5 CI-automated bundling + drift-test is a heavy solution for script sync that simpler conventions could handle.

### Lens: product

**codex (24):**
- Central premise only partially sound: terminal friction is one bottleneck, but the workflow also adds consent decisions, vendor setup, posture checks, gitleaks interpretation, sidecar review, trust calibration; the thin slice may measure novelty-willingness more than durable adoption.
- Thin-slice probe is structurally biased against the final product (omits verification, the most trust-critical step); a reject may teach "unverified output is untrusted" not "deep review lacks value".
- Underestimates the trust cost of per-vendor egress decisions at run time (DPA scope, retention, sensitivity uncertainty) — can suppress use or shift risk to operators.
- Affected people include downstream teams whose work/reputations are influenced by cross-model critiques; false positives/confabulated objections can slow decisions or undermine confidence even when tagged unverified.
- Consent/audit protects vendor egress better than internal reputational/governance consequences; committed sidecars become review history — a governance issue, not just leak/security.
- Verifier accuracy target may create false confidence; ≤5% on a small curated corpus with synthetic agy items may not generalize to judgment-heavy plans.
- Plan drifts from "learn team-wide value" into platform/harness hardening (grok sandbox, agy auth, CI rebundle, drift, filename semantics, rotation, promotion infra) — increases investment before value proven.
- Dogfood denominator weak: counting prior high-stakes plans + skipped opportunities post-hoc without a "high-stakes" definition or prospective log makes the decision negotiable.
- ≥5 verified runs in 2 weeks may not distinguish product pull from compliance/novelty; a small team can coordinate-dogfood.
- Assumes more arms are valuable, but value may come from one trusted complementary reviewer + verification; adding grok/agy before proving verified findings change decisions risks "decorrelation theater".
- Separates decorrelation from value but the ≥30% metric re-conflates them (measures incremental findings, not improved decisions/reduced defects/time saved).
- Fallback paths are product-confusing (panel-only, reduced-confidence, draft, verified, unavailable preview, unavailable model, provisional single-arm, synthetic calibration, beta/stable) — together hard to reason about.
- Graceful gitleaks-absent weakens the safety story; the escalated ack may become a checkbox normalizing egress without scanning under deadline pressure.
- Too much responsibility on individual devs for vendor config/policy; trust would be stronger with central governance + approved/unapproved status.
- Strategic behavior risk: authors may write plans to satisfy reviewers / over-index on quote-groundable claims / add defensive detail.
- Work drifts toward "agentic review infrastructure platform"; first milestone should be narrower (prove verified output changes decisions).
- Sequencing tension: Phase 1 is meant to be cheap but requires consent UX, gitleaks degradation, harness mod, bundling, CI drift, docs, state machine — not a cheap probe; opportunity cost should be explicit.
- "Unverified dump never ships" vs the thin slice creating durable `.deep-review-draft.md` artifacts that can be copied/committed/cited; treat thin-slice artifacts as potentially influential.
- Calendar dependency can distort learning; a slipped schedule forces strategic decisions from a degraded arm set.
- Doesn't define who decides a finding is "decision-changing"; orchestrator → overstates importance, user → less turnkey; the strongest value metric depends on this.
- "turnkey high-stakes plan review" may exceed what the system can responsibly deliver; position as structured review assistance, not decision-grade assurance.
- Trust model privileges document-grounded evidence; many senior findings (stakeholders, incentives, timing, governance, second-order harms) lack quotes and may be filtered out.
- Affected teams may experience review latency as governance drag; teams may avoid labeling work "high-stakes" to dodge process.
- No explicit kill criteria after the verified version ships beyond weak adoption/verifier gates; tool may persist because infrastructure exists.

**gemini (10):**
- "Friction-is-the-bottleneck" may be wrong; the real barrier may be triaging noisy findings → "adoption debt" where users bounce early and never return.
- Verification "phantom trust": a secondary LLM pass may validate subtle confabulations, leading reviewers to defer accountability to a hallucinated CONFIRMED.
- Decentralizing data-handling to individual envs (grok/Antigravity) creates an unmanageable "weakest link" IP/PII egress posture.
- "turnkey" undermined by an onboarding tax (manual setup of 3+ tools) → restricts adoption to power users.
- F5 graceful degradation prioritizes speed over safety → path of least resistance to accidental exposure.
- Thin-slice unverified dump risks poisoning the brand; a noisy first experience compromises Deep Review's reputation before verification lands.
- Automated tagging may induce automation bias → reviewers skim/skip validation once a tool shows CONFIRMED.
- "Usage lift" during dogfood may capture curious/opportunistic runs, not decision-grade value → false-positive signal for full investment.
- `.deep-review-draft.md` suffix is too subtle for high-stakes; PR/grep readers may miss the distinction → accidental trust in unverified critiques.
- 2026-06-18 cutoff creates a forced-march to Antigravity that may compromise posture-floor validations.

### Lens: adversarial

**codex (90):** *(high-volume / over-emitting — read as leads; heavily overlaps the panel + other lenses)*
- Dogfood gate assumes a reliable denominator exists; never defines who classifies a plan high-stakes, where skipped plans are recorded, or how to prevent survivorship bias.
- Baseline comparison weak: prior 4-week usage may be near-zero due to workload/holidays/deadlines/cutoff, not friction; ≥2-dev "materially higher" can be noise unless population is pre-registered.
- Rejection of the cheaper pre-filled-command probe is incompletely justified; a staged probe with telemetry could test friction before mutating/bundling the canonical harness.
- U5 modifies canonical `panel-critique.sh` before the dogfood gate validates the hypothesis — irreversible shared-surface change.
- CI rebundle can mutate the working tree (bad CI pattern); surprise failures for unrelated canonical edits.
- Bundled-copy normalized equality ignores semantic drift (env assumptions, exec bits, shebang, shell options, Python deps, relative paths); copy equality ≠ works inside an installed skill.
- P0 egress mitigation requires correct `--models` before any prompt reaches an arm; no negative network/API-call test, only absence of local records.
- Inspecting /tmp records to prove no egress is insufficient — a failing/malformed arm could egress then fail before writing records.
- Consent gate assumes multi-select + Cancel + default-none within a 4-option cap; if Cancel consumes an option, 4 models + Cancel breaks the cap.
- Responsibility ack is legally/operationally thin; no persistent record of exact prompt text, vendors, user identity at consent in the draft.
- Graceful gitleaks degradation shifts risk to the user but doesn't mitigate it; only control is a warning + audit field.
- Defers scanning the sidecar even though it can contain new sensitive content from model outputs/quotes/hallucinated secrets.
- Sidecar leak mitigation relies on user judgment before commit, but the workflow is designed to create durable commit-as-audit artifacts; safer default: scan/ write outside repo until scan passes.
- Assumes `gitleaks detect --no-git --source <plan>` works on a single md file with line-level previews; behavior may differ by version / treat --source as a dir.
- gitleaks isn't a PII detector; consent language overstates protection.
- agy "no offline signal" branch may incorrectly block authed users if the CLI only exposes safe local status; no user-consented auth-status probe separate from content egress.
- env-detect no-leak test only checks a grok fixture token; doesn't cover shell tracing/error paths/JSON failures/permission errors/malformed creds/vendor stderr.
- Detection may still execute vendor binaries if implemented carelessly; tests should assert no codex/grok/agy process spawned.
- grok retention "confirmed acceptable" without recording policy version/date/tier/DPA/scope; a future change invalidates it undetected.
- grok smoke test validates a small sentinel suite then uses it as a posture constant; doesn't cover plan-doc prompt injection, hidden tool affordances, future CLI updates.
- agy posture floor is best-effort prompt-side, yet Phase 2 proceeds if U2 passes a sentinel suite; doesn't cover future CLI changes / prompt injection.
- Verification is Claude-based against the same context; treated as a reliable arbiter after a small corpus; doesn't address shared blind spots with the initial Claude panel.
- Verifier rate gate permits promotion with synthetic agy items; synthetic phrasing ≠ real agy confabulation coverage.
- ≈20 items N=3 too small for a ≤5% claim; one miss moves the rate materially; no CIs/stopping rules.
- Rates measured on curated findings; production findings may be longer/compound/vague/partially true; no partial-grounding tests.
- Inline-quote presence inadequate for CONFIRMED; a quote can exist while interpretation is unsupported/inverted/out-of-context.
- "blind to producing model" but voice/style/filenames in records may reveal the producer; no normalization/metadata-strip required.
- Thin-slice emits unverified findings to chat + draft sidecar; users may act on plausible false findings — violates the "unverified dumps never ship" claim in any user-facing sense.
- A prominent banner may not prevent misuse under review pressure; safer slice would suppress sidecar writing or require verification checkboxes.
- Calendar fallback race: signal gathered on codex+gemini before cutoff may not transfer to the eventual codex+grok shape.
- Dogfood can greenlight Phase 2 on codex+gemini ergonomics while shipped value depends on codex+grok+agy + verification — tested ≠ built product.
- Explicit-invocation metrics from committed sidecars miss F4 cancel / failed pass-1/2 / panel-only / uncommitted runs → success bias.
- Manual counting from committed sidecars conflicts with privacy: incentivizes committing artifacts even when preview was unavailable / sidecars quote sensitive text.
- coverage `full|reduced-confidence|panel-only` hides quality differences (one good model + two skipped ≠ two noisy + one timeout).
- No-cross-vendor-retry: a transient failure produces reduced-confidence output that looks complete; safer to fail closed / require explicit acceptance before writing.
- Headless ce-doc-review dependency treated as stable with contract tests late in Phase 4; envelope drift during Phase 1 breaks the thin slice before the guard lands.
- Pass-1 failure blocks the gate, but also means cross-model review can't diagnose a Claude panel failure; panel-first hard dependency unjustified.
- Modifying the brainstorm in U2/U13 creates a paper trail that makes assumptions look resolved before operational evidence.
- Phase 0/1 parallel but Phase 1 includes env-detect stubs + onboarding docs affected by U2 → risks shipping known-incomplete docs.
- `Bash(bash *panel-critique.sh)` may be too broad; a malicious/accidental matching path could execute unless absolute path enforced.
- Comma-separated model subset through shell without strict validation/quoting → command-injection risk if labels/future IDs mishandled.
- Plan paths passed to shell without robust quoting/normalization/symlink handling / dash-leading filename protection.
- /tmp records collide across concurrent runs/users unless CMRE_OUT_DIR unique; no isolation/cleanup/permissions/stale protection.
- Raw /tmp records may contain plan content + findings; retention/permissions/cleanup unspecified.
- Rotation keeps last five `.deep-review.md`; older rotated files may contain sensitive quotes; deleting beyond five is an unvalidated retention policy.
- Leaving thin-slice drafts in place preserves potentially false + sensitive artifacts; values dogfood evidence over cleanup without user confirmation.
- "do not modify .gitignore" dismisses a cheaper safety alternative (default-ignore generated sidecars, deliberate git add -f).
- Rejecting hard-block on missing gitleaks prioritizes measurement over safety for a high-stakes tool.
- No defined behavior if model output is malformed but contains useful findings (drop loses signal / pass-through breaks verification).
- "decision-changing-union" underspecified; reconciliation can overstate volume / merge incompatible findings / bury a critical confirmed issue.
- Inline-heredoc rubrics make drift harder to review/test independently; standalone-rubric copy may be safer for auditability.
- Build-time copying shared eval harness into a skill imports eval-specific assumptions into runtime; a skill-specific wrapper around a stable API boundary is safer.
- ≥30% metric can reward noisy models producing many findings; ignores reviewer time/severity/duplicate/false-positive cost.
- "first deep review within 30 minutes" can be met while security posture / consent comprehension / sidecar handling are poor.
- No cost/token visibility before egress; cost estimation out of scope; users consent without knowing size/cost/latency of a large plan.
- agy `--add-dir <doc-dir>` can expose adjacent sensitive files; prompt says read one path but the permission grants broader fs access.
- U2 measures -p cap for ≥200 KB plans, but docs can be larger / include linked context; no fallback besides underspecified --add-dir.
- Line-numbered gitleaks previews may be insufficient for consent; gate may hide risk behind terse preview lines.
- Promotion can pass with "eligible (gemini-voiced + agy-synthetic); agy-real pending" — contradicts the adequate-agy-representation requirement (loophole).
- Verifier >5% fallback default-tags NEEDS-HUMAN → product may no longer deliver the verified sidecar; no re-evaluation of whether to ship.
- Contract tests over SKILL.md text can pass while agent behavior / shell scripts violate the contract.
- No end-to-end test with fake vendor CLIs asserting exact stdin/argv per model — the most direct cheap consent-bound-egress test.
- Declined consent → panel-only chat (no sidecar), but F3 zero-CLI writes `.panel-review.md`; inconsistent audit expectations.
- Cancel produces no `.deep-review` sidecar; unclear whether pass-1 panel findings are persisted → users may lose audit data.
- New beta skill with disable-model-invocation relies on explicit invocation/discoverability → biases dogfood toward motivated users, under-tests broader workflow.
- No rollback criteria if Phase 1 reveals safety incidents / leaked artifacts / consent confusion; only routes on usage lift + debrief.
- "Phase 2 must not begin until dogfood proceed recorded" has no artifact/owner/CI/PR gate enforcing the decision record.
- U5's unresolved `--models` guard vs `arms.py run-arm` choice is load-bearing for consent safety; deferring invites inconsistent P0 implementation.
- Model availability shown in the gate may not match pass-2 execution; auth can expire between detection and dispatch; no post-consent preflight.
- No partial consent revocation during long pass-2; once selected, all cells run unless manually killed.
- Vendor output may contain copyrighted/confidential provider material; sidecars may commit raw findings/quotes.
- "no live calls before consent" but pass-1 Claude already processes the plan; if Claude is an external processor in some deployments, the consent model is incomplete.
- Assumes devs understand "paid plan + DPA where applicable"; tool doesn't know which vendors are actually covered for the current account → uninformed consent.
- Doesn't record vendor CLI versions in the sidecar; later investigations can't reproduce posture/auth/calibration context.
- Doesn't hash plan content or record git SHA; sidecar can detach from the exact reviewed version.
- `user` from `git config user.name` is unreliable identity (unset/shared/pseudonymous) for consent/audit.
- "coverage: full" can be assigned even if Phase 0 dropped agy/grok — full relative to current config misleads vs intended 3-arm.
- No downgrade path for model removal after promotion (no runtime kill switch / version pinning) if grok/agy posture later fails.
- Doesn't pin vendor CLI / gitleaks / harness dependency versions; auto-upgrades can invalidate U1/U2 validation.
- Doesn't specify how bundle-harness.sh avoids copying local uncommitted experimental changes into the bundle.
- Assumes raw records remain in /tmp while sidecars in repo, but verification/reconciliation may need records later; no durable provenance link (record hashes).
- The cheaper safer alternative of a sandboxed fake-CLI harness for Phase 1 isn't considered (validate orchestration/consent/parsing/sidecar before real egress).
- User-facing beta doc created before verification exists → normalizes use of an unverified workflow (copy, not capability).
- "unverified dump never ships" vs Phase 1 shipping a beta that writes unverified drafts — terminology dodge, not a safety boundary.
- No ownership for debrief collection / structured debrief storage → OD-1's routing decided from anecdotes.
- Doesn't require reviewing negative outcomes from non-adopters — the key population for the friction test.
- Adoption signal starts after verification landing — by then Phase 2/3 investment already happened; can't protect against the heavy build not paying back.
- No security review required before enabling grok/agy egress of internal high-stakes plans.
- "internal Blueprint plan content" boundaries undefined; some plans may include customer data/credentials/regulated/legal strategy outside the confirmed grok retention assumption.
- The deferred opt-in-none vs opt-out flip criterion is itself a consent-risk forcing function left undefined; safer to keep default-none permanently unless security approves.

**gemini (11):**
- Unstated assumption: the ce-doc-review headless envelope is an immutable contract; any upstream format change breaks Pass-1 parsing before the gate opens.
- Unstated assumption: offline auth detection is possible for all CLIs; a network-only session check renders that arm permanently "missing" under R9.
- Audit leaks: U10 requires inline-quoted snippets for CONFIRMED; a secret gitleaks missed gets permanently committed to git history as an "audit" record.
- Verification hallucination: the blind verifier may hallucinate a CONFIRMED match for a plausible-but-false gemini/grok finding → dangerous false security.
- Sync-block latency: parallelism doesn't mitigate sequential six-lens execution per model; a single rate-limit/high-latency turns "turnkey" into a long wait exceeding the attention hop.
- Graceful-degradation risk: F5 relies on manual audit (high-variance), failing the junior/rushed devs who are the primary users of turnkey automation.
- Stale-artifact pollution: U11 leaves `.deep-review-draft.md` in the repo even after a verified review → persistent confusion + risk from confabulated findings in the audit trail.
- Cheaper/safer alternative: the dismissed pre-filled-bash-command probe provided a superior security boundary (user stays in the egress loop), undervalued vs attention friction.
- Irreversible step: U5 modifies the canonical shared harness before the dogfood gate validates the value hypothesis.
- Bundling debt: checking in duplicated harness copies (vs submodule/external versioning) creates sync debt + bloat before value proven.
- Metric bias: the adoption signal counts only committed sidecars, ignoring devs who found it unhelpful and deleted output → success-only telemetry bias.

---

## Notes for the dogfood debrief (skill-self signal)

- **The turnkey dispatch was blocked by Claude Code's auto-mode egress classifier**, even after the in-skill consent gate granted consent — the binding friction in this run was the harness hard-block, not the terminal hop the thin slice was designed to remove. The plan's "egress = consent" contract is silently overridden by the harness; the U5 dispatcher as designed cannot run turnkey under default auto-mode. This is an unhandled state worth a P1 in the next revision and belongs in the OD-1 debrief.
- Both arms returned `ok` (coverage: full). codex over-emitted hard (90 adversarial findings); gemini was terser (51 total). This volume asymmetry is itself the confabulation/triage-noise risk the panel's product-lens findings flag.
