# shellcheck shell=bash
# flake.lock node-count and file-size budget guard.
# Usage: lefthook-nix-flake-lock-budget [flake.lock]

lock="${1:-flake.lock}"

# V1: no arg and no flake.lock in cwd -> exit 0
if [ $# -eq 0 ] && [ ! -f "$lock" ]; then
  exit 0
fi

# V2: explicit path that doesn't exist -> exit 1
if [ $# -gt 0 ] && [ ! -f "$lock" ]; then
  echo "error: $lock: not found" >&2
  exit 1
fi

# V9: validate budget env vars are positive integers
max_nodes="${FLAKE_LOCK_MAX_NODES:-20}"
max_bytes="${FLAKE_LOCK_MAX_BYTES:-32768}"

if ! [[ "$max_nodes" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: FLAKE_LOCK_MAX_NODES must be a positive integer, got: $max_nodes" >&2
  echo "hint: export FLAKE_LOCK_MAX_NODES=20" >&2
  exit 1
fi

if ! [[ "$max_bytes" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: FLAKE_LOCK_MAX_BYTES must be a positive integer, got: $max_bytes" >&2
  echo "hint: export FLAKE_LOCK_MAX_BYTES=32768" >&2
  exit 1
fi

# V8: validate JSON
if ! jq empty "$lock" 2>/dev/null; then
  echo "error: $lock: invalid JSON" >&2
  exit 1
fi

# V3/V4: node count check (V7: fail-fast on first violation)
node_count=$(jq '.nodes | length' "$lock")

if [ "$node_count" -gt "$max_nodes" ]; then
  echo "flake.lock budget exceeded: $node_count nodes (max $max_nodes)" >&2

  # V10: print top-5 largest subtrees by transitive node count
  jq -r '
    .nodes as $all |
    def reachable:
      . as $start |
      {seen: {}, q: [$start]} |
      until(.q | length == 0;
        .q[0] as $n | .q |= .[1:] |
        if .seen[$n] then .
        else
          .seen[$n] = true |
          .q += [
            ($all[$n].inputs // {} | to_entries[].value) |
            if type == "string" then . elif type == "array" then .[0] else empty end
          ]
        end
      ) | [.seen | keys[]] | length;

    [$all | keys[] | select(. != "root")] |
    map({name: ., count: (. | reachable)}) |
    sort_by(-.count) | .[0:5][] |
    "  \(.name): \(.count) nodes"
  ' "$lock" >&2
  exit 1
fi

# V5/V6: file size check
file_size=$(wc -c <"$lock" | tr -d ' ')

if [ "$file_size" -gt "$max_bytes" ]; then
  echo "flake.lock budget exceeded: $file_size bytes (max $max_bytes)" >&2
  exit 1
fi
