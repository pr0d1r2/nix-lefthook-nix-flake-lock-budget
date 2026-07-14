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
| B1 | 2026-07-14 | CI failed (exit 127): `lefthook.yml` ran `lefthook-markdownlint-agentic`, but that binary is not in the ci devShell (`nix-dev-shell-agentic` ships only `lefthook-markdownlint`/`lefthook-yamllint`). README.md also had MD014 dollar-prefix lint violations exposed once the hook ran. | Added `nix-lefthook-markdownlint-agentic` flake input and its package to `ciPackages` so the binary is on PATH; dropped `$ ` command prefixes in README.md code blocks. |
