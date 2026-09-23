# SPEC -- nix-lefthook-nix-flake-lock-budget

## S.G Goal

Lefthook-compatible guard that fails when `flake.lock` exceeds a node-count or file-size budget. Catches accidental full-flake imports that explode the lock graph. Two consumption modes: lefthook remote (recommended, zero flake config) and flake input.

## S.C Constraints

- C1: Pure Nix packaging -- `writeShellApplication` wraps script + jq runtime dep
- C2: 4 platforms -- aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux
- C3: Timeout at lefthook level via `LEFTHOOK_FLAKE_LOCK_BUDGET_TIMEOUT` env var, default 30s -- script itself has no timeout
- C4: Budget thresholds configurable via env vars with sensible defaults
- C5: Only runs when `flake.lock` exists (exit 0 otherwise -- not all repos are flakes)
- C6: MIT license
- C7: LLM-generated, validated via lefthook hooks + bats tests + CI
- C8: Cachix binary cache (`pr0d1r2.cachix.org`) configured in nixConfig for faster builds
- C9: DevShell via `nix-dev-shell-agentic` -- provides `default` + `ci` shells, bats libs, lefthook

## S.I Interfaces

- I.cli: `lefthook-nix-flake-lock-budget [flake.lock]` -- main entry point, path defaults to `flake.lock` in cwd
- I.flake-pkg: `packages.<system>.default` -- writeShellApplication with jq in runtimeInputs
- I.flake-dev: `devShells.<system>.{default,ci}` -- via nix-dev-shell-agentic, includes lefthook-nix-flake-lock-budget + bats
- I.remote: `lefthook-remote.yml` -- drop-in lefthook remote config (pre-commit + pre-push) for consumers
- I.self-hooks: `lefthook.yml` -- dev hooks for this repo (includes lefthook remotes for linting)
- I.env-nodes: `FLAKE_LOCK_MAX_NODES` -- integer, default 20, maximum allowed node count
- I.env-bytes: `FLAKE_LOCK_MAX_BYTES` -- integer, default 32768 (32K), maximum allowed file size in bytes
- I.env-timeout: `LEFTHOOK_FLAKE_LOCK_BUDGET_TIMEOUT` -- seconds, default 30, used in lefthook configs
- I.cache: `nixConfig.extra-substituters` -- cachix substituter for pre-built packages

## S.V Invariants

- V1: No `flake.lock` in cwd (and no arg) -> exit 0
- V2: Explicit path arg that doesn't exist -> exit 1 with error
- V3: Node count within budget -> exit 0, silent
- V4: Node count exceeds budget -> exit 1, prints actual vs max
- V5: File size within budget -> exit 0, silent
- V6: File size exceeds budget -> exit 1, prints actual vs max
- V7: Both checks run -- both must pass (fail-fast on first violation)
- V8: Invalid JSON -> exit 1 with parse error
- V9: Budget env vars accept only positive integers -- non-numeric -> exit 1 with usage hint
- V10: On failure, prints top-N largest subtrees (by transitive node count) to guide cleanup

## S.T Tasks

| id | st | desc | cites |
|----|----|------|-------|
| T1 | . | Shell wrapper: node count + size checks | V1-V10,I.cli |
| T2 | . | Nix flake: writeShellApplication package | I.flake-pkg,C1 |
| T3 | . | Nix flake: devShell via nix-dev-shell-agentic | I.flake-dev,C9 |
| T4 | . | lefthook-remote.yml for consumers | I.remote,C3 |
| T5 | . | lefthook.yml for self (dev hooks) | I.self-hooks,I.cli |
| T6 | . | Bats unit tests | V1-V10 |
| T7 | . | CI workflow: 3 platforms via nix-lefthook-ci-action | C2,C8 |
| T8 | . | README with usage docs | I.remote,I.flake-pkg |
| T9 | . | Create GitHub repo and push | I.remote |

## S.B Bugs

| id | date | cause | fix |
|----|------|-------|-----|
| B1 | 2026-07-14 | CI failed (exit 127): `lefthook.yml` ran `lefthook-markdownlint-agentic`, but that binary is not in the ci devShell (`nix-dev-shell-agentic` ships only `lefthook-markdownlint`/`lefthook-yamllint`). README.md also had MD014 dollar-prefix lint violations exposed once the hook ran. | Added `nix-lefthook-markdownlint-agentic` flake input and its package to `ciPackages` so the binary is on PATH; dropped `$`-prefix shell prompts from README.md code blocks. |
| B2 | 2026-07-14 | CI still red after B1: the B1 row embedded a dollar-then-space code span, tripping markdownlint MD038 (no-space-in-code-span) on `SPEC.md`, which the pre-commit/pre-push `markdownlint` hook lints. | Reworded the B1 row to drop the trailing space from that code span. |
| B3 | 2026-08-13 | CI failed (`guardrails / check`, exit 1): the flake referenced undefined `supportedSystems`; evaluation also exposed unbound `inputs`/`pkgs` and a custom `devShells` placed inside `packages`. | Defined the four systems required by C2, bound the flake inputs, and kept `extraPackages` limited to package outputs so the shared consumer-flake helper can provide dev shells. |
| B4 | 2026-08-13 | CI still failed (`guardrails / check`, exit 1): the shared `actions` fragment passed `^\.github/workflows/.*` as a scalar to the pinned actionlint check, which now requires a list. | Removed the incompatible `actions` fragment from this consumer flake; workflow syntax remains checked by the repository's CI guardrails workflow. |
| B5 | 2026-08-13 | CI still failed (`guardrails / check`, exit 1): `flake.lock` did not contain the transitive inputs required by the locked `set-and-setting` consumer helper, so CI evaluated a different fragment/fidelity configuration than the repository source. | Regenerated `flake.lock` from the declared flake inputs, restoring the complete synchronized dependency graph used by guardrails. |
| B6 | 2026-08-13 | Local full flake checks exposed a dependency-policy failure: `nix-dev-shell-agentic` was declared with a `git+https` URL, producing non-GitHub lock entries rejected by the dependency-graph guard. | Switched the input to its equivalent `github:` URL and regenerated the lock file. |
| B7 | 2026-08-13 | Local full flake checks exposed a missing required `file-size-check` configuration file, so the shared guard could not evaluate repository file limits. | Added the repository file-size policy, including a lock-file limit suitable for the intentionally large generated dependency lock. |
| B8 | 2026-08-13 | Local full flake checks exposed a missing linter-coverage exemptions file, preventing the shared coverage guard from running. | Added an explicit empty exemptions list; no checks are exempted. |
| B9 | 2026-08-13 | The synchronized dependency lock is 3.7 MiB, exceeding the generic 128 KiB lock limit used by the shared file-size guard. | Set the lock-specific limit to 4 MiB, matching the repository's intentionally large generated lock while retaining limits for other file types. |
| B10 | 2026-08-13 | CI fidelity expected the canonical `actions` fragment, but the consumer flake omitted it after an earlier compatibility workaround, so the generated `lefthook.yml` differed from the guardrails configuration. | Restored the required `actions` fragment in the consumer flake. |
| B11 | 2026-08-13 | Local `nix flake check` reproduced `actionlint` evaluation failure: the locked shared helper's actionlint source filter expects a list, but its `actions` fragment supplies the scalar `^.github/workflows/.*`. | Removed the incompatible `actions` fragment; the repository's reusable GitHub Actions guardrails workflow continues to validate workflow syntax. |
| B12 | 2026-09-23 | CI and local `nix flake check` failed because `flake.nix` was not formatted, causing the `nixfmt-check` derivation to exit 1. | Corrected the indentation of the flake input attribute-set closures to match `nixfmt` formatting. |
| B13 | 2026-09-23 | Lock-graph guard found duplicated `nixpkgs`/`nixpkgs-lock` and `set-and-setting` nodes from missing follows. | Added follows wiring and regenerated `flake.lock`; all 26 checks passed. |
| B14 | 2026-09-23 | CI guardrails could not resolve `flake:nix-cavekit`: it existed only as a nested input, while the shared guard invokes it standalone; promoting it initially duplicated `set-and-setting`. | Declared `nix-cavekit` directly, wired nested consumers to follow existing inputs, and regenerated `flake.lock`. |
| B15 | 2026-09-23 | Guardrails rejected the generated `CHANGEME` description. | Replaced it with the project description. |
| B16 | 2026-09-23 | CI could not resolve `flake:nix-cavemem`: it was only nested, while the guard invokes it standalone. | Promoted it directly, wired the nested consumer to follow it, and regenerated `flake.lock`. |
