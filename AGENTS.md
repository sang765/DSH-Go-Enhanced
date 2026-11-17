# AGENTS.md

dsh-Go is the mobile app for DeepSeek Harness: a Flutter native UI + a pure Dart client + a patched DSH engine runtime. The Android build runs `dsh web` inside PRoot; the HarmonyOS build shares the same Dart code, with ArkTS as the host (`app/ohos/`), and the engine runs in Node inside the app process (`runtime/ohos/`, see [docs/architecture.md §3B](docs/architecture.md)). Before making changes, read [CONTRIBUTING.md](CONTRIBUTING.md) (contribution and verification contract) and [docs/architecture.md](docs/architecture.md).

## Repository layout

```
app/                           Flutter app: native UI, Riverpod state, l10n, phone control
app/lib/l10n/parts/            Chinese/English ARB inputs for UI strings
app/ohos/                      HarmonyOS ArkTS host project (not read on Android)
packages/dsh_client/           Pure Dart client: HTTP/SSE, mux, session and delete APIs
packages/dsh_remote/           Remote transport: WebRTC / LAN / TURN / relay
runtime/                       Patched DSH engine runtime
runtime/bridge/dsh-go-bridge/  HTTP bridge between app and engine (/dsh-go/v1/*, includes the session-delete route)
runtime/patches/               Engine patches and their pins.json (patches pinned to versions; targetSets split android / ohos)
runtime/ohos/                  HarmonyOS native engine: Node host, virtual process, lifecycle, runtime composition
sdk/plugin-kit/                Plugin SDK
tooling/                       APK build and build-number scripts; tooling/ohos/ is HarmonyOS build, ArkTS checks, and gates
docs/                          Architecture, releases, roadmap, user guides (HarmonyOS guide in docs/guide/harmony/, design docs in docs/design/harmonyos/)
```

## Commands

Pick verification based on the change surface, and record the actual commands run and their results in the PR/report. Full details in [CONTRIBUTING.md](CONTRIBUTING.md).

```bash
(cd app && flutter pub get && flutter analyze && flutter test)   # Flutter app
(cd packages/dsh_client && dart pub get && dart analyze && dart test)
(cd packages/dsh_remote && dart pub get && dart analyze && dart test)
(cd sdk/plugin-kit && npm install && npm test)
node --test runtime/tests/*.test.mjs                               # Engine bridge/patch tests
python3 app/tool/l10n_merge.py --check                             # String generation check
python3 app/tool/guide_sync.py --check                             # User guide sync check
tooling/build-apk.sh --build-name <x.y.z>                          # Build APK
tooling/ohos/check-arkts.sh --sdk <OpenHarmony SDK> --hms-stubs    # HarmonyOS strict ArkTS compilation
bash tooling/ohos/run-gates.sh --config <inputs.json> --out <dir>  # HarmonyOS full gates (tooling/ohos/GATES.zh.md)
```

CI (`.github/workflows/ci.yml`) runs general checks plus the parts a PR touches, and the full suite on `main`; results show up as `CI OK`. It never touches real devices or real accounts — green does not mean it works on the phone.

## Hard rules

### No external PRs accepted (highest priority)

- This repository **does not accept any external Pull Requests for now** (code, docs, config, templates — none of it).
- **Merging any external PR is forbidden**: do not use `gh pr merge`, the GitHub API, web merges, rebase, or cherry-pick to bring external commits into `main`.
- **Do not create PRs on the user's behalf**, unless the user explicitly asks in the current conversation.
- When an external PR arrives: close it and reply "External PRs are not accepted at this time; please use issues for suggestions." The entry check (`.github/workflows/pr-gate.yml`) auto-closes external PRs; handle manual cases under the same policy. Never "merge first, discuss later".
- Do not wrap an existing issue implementation into a PR and merge it just because the implementation exists.

### Source, generated artifacts, and runtime patches

- Never hand-edit generated artifacts: `app/build/`, `.dart_tool/`, generated l10n outputs, etc.; change the inputs, then run the corresponding generator.
- UI strings are edited in `app/lib/l10n/parts/*.arb`, Chinese and English in sync, then run `python3 app/tool/l10n_merge.py`; do not hand-edit the generated results.
- User guides are edited in `docs/guide/`, then run `python3 app/tool/guide_sync.py`. The HarmonyOS guide lives in `docs/guide/harmony/`; when a feature differs on HarmonyOS, update both guides.
- Engine patches live in `runtime/patches/`: keep patch files in sync with `pins.json`, and do not hand-edit artifacts covered by a patch. New patches must be registered in `pins.json`'s `targetSets` (`android`, `ohos`, or both); rtbuild refuses to build with unregistered patches.
- For the plugin-teaching skill, edit `sdk/plugin-kit/skill/` or the SDK's corresponding inputs, then run `node sdk/plugin-kit/scripts/sync-skill.mjs`.

### Behavior and contracts

- Changes to the client, bridge, or plugin protocols must check callers on the other side and backward compatibility at the same time.
- For dangerous operations (deleting sessions, permissions, credentials), defer to the actual host/engine answer; never substitute local inference. Failures need stable error codes — never swallow them silently.
- UI strings stay in sync across both languages (`app/lib/l10n/parts/*.arb` and the matching `.en.arb`).
- Bilingual docs stay in sync: README, CONTRIBUTING, SECURITY, docs/guide in both Chinese and English.

### HarmonyOS

- Feature parity between HarmonyOS and Android is the goal, UI-first. Features that can be implemented go through the same UI; only when that is impossible, hide them per-feature using `androidSystemFeaturesProvider` / `operatingSystemProvider` (`app/lib/state/android_features.dart`) — never globally enable or disable, and document the alternative in the HarmonyOS guide.
- `androidSystemFeaturesProvider` is false on both HarmonyOS and iOS. Branches exclusive to HarmonyOS check `operatingSystemProvider == 'ohos'`; do not use its false as a stand-in for HarmonyOS.
- HarmonyOS changes must not alter Android's runtime bytes or behavior; the gates' Android comparisons (`android-targets`, `android-version-tree`) use main as the baseline.
- Write ArkTS in strict mode: explicit types for for-of variables, `as Error` when passing a subclass to an `Error` parameter, no `this` in static methods. After touching `app/ohos/`, run `check-arkts.sh`.
- Signing material (`.p12`, certificates, profiles) stays outside the repo only (`DSH_OHOS_SIGN`); never commit it, never echo it.

### Credentials and privacy

- Never record, echo, or persist full API keys, tokens, cookies, or login states.
- Manually inspect diagnostic bundles and logs before sending them out; automatic redaction is not a guarantee.

### Git safety

- **Level the baseline before starting work**: after `git fetch origin main`, sync the current branch to the latest `origin/main` (fast-forward with `git merge --ff-only` when possible); inspect, change, and open PRs on the latest baseline. Never stack work on a branch that is behind `main` — otherwise you risk re-implementing what `main` already fixed, for nothing.
- Handle uncommitted changes before leveling: back up your own changes (patch or temporary copy) before fast-forwarding; never discard, reset, stash, or overwrite uncommitted changes belonging to the user or another task — if you cannot level the baseline, stop and ask. By default, create an isolated work branch from the latest `origin/main`.
- After work is committed and merged, clean up the temporary worktrees and branches created for it; before cleanup, confirm the commits landed in the target and nothing is unsaved or unpushed. Never force-delete a worktree containing changes, and never delete other tasks' branches.
- After merging and cleanup, fetch the latest `main` again and sync the clean main worktree using fast-forward only; report the final commits and anything left uncleaned. Keep unrelated changes in the main worktree and explain them — never lose work just to look "clean".
- Stage explicit paths only; no `git add .` / `git add -A`.
- No commit, push, tag, or release unless asked.
- No force-pushing `main` or rewriting shared history unless the user explicitly asks in the current conversation; after a rewrite, rebuild the affected branches and PRs.

### Real-device verification

- Flutter widget tests need a Flutter engine for the matching architecture; when only the desktop (x86_64) engine exists and the device is arm64, explicitly write "not run" and why.
- Changes to phone control, PRoot, direct launch, or update installation must be verified on a real device; desktop results are no substitute.
- HarmonyOS system capabilities (HMS, background, notifications, voice, cards) can only be proven on a real device; `--hms-stubs` only makes unofficial declarations compile for callers — compiling is not the same as working.

## Code review principles

When reviewing PRs or changes, hold **no new bugs, minimal necessary changes, keep the code simple** as the core:

1. **Prevent regressions**: prioritize checking for new bugs, races, resource leaks, performance regressions, and compatibility issues; pay special attention to the shared layer's (`packages/dsh_client`, bridge, runtime patches) impact on existing host connection methods.
2. **Avoid over-engineering**: identify duplicate implementations, unnecessary abstractions, redundant wrappers, and over-defensive programming; only report when a simpler equivalent exists, and do not misjudge necessary security validation and error handling.
3. **Strictly control scope**: changes should serve the goal and the related issues, with no unrelated refactors, formatting, dependency upgrades, or other feature changes bundled in; necessary tests and doc syncs excepted.
4. **Ensure substantive value**: watch for dead code, duplicate logic, meaningless splits, and tests without effective assertions; never judge contribution by lines of code or commit counts, and never speculate on contributor motives.
5. **Reviews must be evidence-based**: only report substantive problems introduced by this change, stating the exact location, trigger conditions, and actual impact; prefer minimal fix suggestions.

### Over-defensiveness is also a defect (apply this while writing code)

More defense is not better. The test is one question: **will the thing this branch guards against actually happen?**

- Add defense only for failures you can name a trigger condition for; delete branches whose trigger conditions you cannot name.
- If types, a single entry point, or the existing call order already guarantee it, add no runtime validation, no fallback retries, no multi-layer state machines.
- Error handling has exactly two exits: recoverable gives an actionable result, unrecoverable fails explicitly. No silent swallowing, no infinite retries, and no locking a feature away "for safety".
- Security boundaries (permissions, resource cleanup, external input validation) should be strict where needed, but must leave a recovery path: after a rejection the user has to be able to come back — never permanently stuck.
- New state flags, gates, and handshakes must state clearly "who sets it, who clears it, and what happens if it cannot be cleared"; if you cannot write that clearly, do not add it.

### Build the shortest thing that works first

- No protection the requirements did not ask for: multi-layer retries, fallback paths, redundant validation, layer upon layer of null checks, feature flags.
- Do not invent process for yourself: freeze lists, signing ledgers, state snapshots, acceptance reports — unless the user asks.
- No parallel directories like v1 / v2 / final; edit the original file and let git keep the history.
- When something breaks, read the real output to find the root cause — do not paper over it with retries; change one thing, re-run to confirm, then run a few more times to check stability.
- When this section conflicts with the hard rules above, the hard rules win (Git safety, external PR policy, real-device verification, bilingual sync).

## Skills and workflows

- Internal PRs: follow `.agents/skills/pr` (process, templates, verification records).
- Code review: follow `.agents/skills/review` (evidence first; only substantive problems introduced by this change).
- Bug reports: `.agents/skills/bug`; security audit: `.agents/skills/vuln-check`; broad audit: `.agents/skills/audit`.

## Editing this file

`CLAUDE.md` is a symlink to `AGENTS.md`; edit the real file. Keep every rule self-contained, and link details to the authoritative docs.
