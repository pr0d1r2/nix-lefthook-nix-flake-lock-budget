# nix-lefthook-nix-flake-lock-budget

Lefthook-compatible guard that fails when `flake.lock` exceeds a node-count
or file-size budget. Catches accidental full-flake imports that explode the
lock graph.

## Quick start (lefthook remote)

Add to your `lefthook.yml`:

```yaml
remotes:
  - git_url: https://github.com/pr0d1r2/nix-lefthook-nix-flake-lock-budget
    ref: main
    configs:
      - lefthook-remote.yml
```

No flake input required. The check runs on every commit and push.

## Flake input

```nix
inputs.nix-lefthook-nix-flake-lock-budget = {
  url = "github:pr0d1r2/nix-lefthook-nix-flake-lock-budget";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Add the package to your devShell:

```nix
self.packages.${system}.default
```

## Usage

```console
$ lefthook-nix-flake-lock-budget [path/to/flake.lock]
```

Defaults to `flake.lock` in the current directory. Exits 0 when no
`flake.lock` exists (not all repos are flakes).

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `FLAKE_LOCK_MAX_NODES` | `20` | Maximum allowed node count |
| `FLAKE_LOCK_MAX_BYTES` | `32768` | Maximum allowed file size in bytes |
| `LEFTHOOK_FLAKE_LOCK_BUDGET_TIMEOUT` | `30` | Timeout in seconds (used in lefthook configs) |

## Behavior

- No `flake.lock` in cwd (and no arg): exit 0
- Explicit path that doesn't exist: exit 1 with error
- Node count exceeds budget: exit 1, prints actual vs max and top-5 subtrees
- File size exceeds budget: exit 1, prints actual vs max
- Invalid JSON: exit 1 with parse error
- Non-numeric env vars: exit 1 with usage hint

## Development

```console
$ nix develop       # or: direnv allow
$ bats tests/unit/  # run tests
```

## License

MIT
