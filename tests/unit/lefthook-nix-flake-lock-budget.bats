#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TMP="$BATS_TEST_TMPDIR"
}

# -- V1: no flake.lock in cwd, no arg -> exit 0 --

@test "V1: no flake.lock and no arg exits 0" {
    cd "$TMP"
    run lefthook-nix-flake-lock-budget
    assert_success
}

# -- V2: explicit path that doesn't exist -> exit 1 --

@test "V2: explicit nonexistent path fails" {
    run lefthook-nix-flake-lock-budget /nonexistent/flake.lock
    assert_failure
    assert_output --partial "not found"
}

# -- V3: node count within budget -> exit 0 --

@test "V3: node count within budget passes" {
    cat > "$TMP/flake.lock" <<'JSON'
{
  "nodes": {
    "root": {
      "inputs": {
        "nixpkgs": "nixpkgs"
      }
    },
    "nixpkgs": {
      "locked": {
        "type": "github",
        "owner": "NixOS",
        "repo": "nixpkgs"
      }
    }
  },
  "root": "root",
  "version": 7
}
JSON
    run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_success
}

# -- V4: node count exceeds budget -> exit 1 --

@test "V4: node count over budget fails" {
    cat > "$TMP/flake.lock" <<'JSON'
{
  "nodes": {
    "root": {"inputs": {"a": "a"}},
    "a": {"inputs": {"b": "b"}},
    "b": {}
  },
  "root": "root",
  "version": 7
}
JSON
    FLAKE_LOCK_MAX_NODES=2 run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "3 nodes (max 2)"
}

# -- V5: file size within budget -> exit 0 --

@test "V5: file size within budget passes" {
    cat > "$TMP/flake.lock" <<'JSON'
{
  "nodes": {
    "root": {}
  },
  "root": "root",
  "version": 7
}
JSON
    run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_success
}

# -- V6: file size exceeds budget -> exit 1 --

@test "V6: file size over budget fails" {
    cat > "$TMP/flake.lock" <<'JSON'
{
  "nodes": {
    "root": {}
  },
  "root": "root",
  "version": 7
}
JSON
    FLAKE_LOCK_MAX_BYTES=10 run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "bytes (max 10)"
}

# -- V7: fail-fast on first violation --

@test "V7: node count checked before file size (fail-fast)" {
    cat > "$TMP/flake.lock" <<'JSON'
{
  "nodes": {
    "root": {"inputs": {"a": "a"}},
    "a": {"inputs": {"b": "b"}},
    "b": {}
  },
  "root": "root",
  "version": 7
}
JSON
    FLAKE_LOCK_MAX_NODES=2 FLAKE_LOCK_MAX_BYTES=10 run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "nodes (max 2)"
    refute_output --partial "bytes"
}

# -- V8: invalid JSON -> exit 1 --

@test "V8: invalid JSON fails" {
    echo "not json" > "$TMP/flake.lock"
    run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "invalid JSON"
}

# -- V9: non-numeric env vars -> exit 1 --

@test "V9: non-numeric FLAKE_LOCK_MAX_NODES fails" {
    cat > "$TMP/flake.lock" <<'JSON'
{"nodes": {"root": {}}, "root": "root", "version": 7}
JSON
    FLAKE_LOCK_MAX_NODES=abc run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "positive integer"
}

@test "V9: non-numeric FLAKE_LOCK_MAX_BYTES fails" {
    cat > "$TMP/flake.lock" <<'JSON'
{"nodes": {"root": {}}, "root": "root", "version": 7}
JSON
    FLAKE_LOCK_MAX_BYTES=xyz run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "positive integer"
}

@test "V9: zero FLAKE_LOCK_MAX_NODES fails" {
    cat > "$TMP/flake.lock" <<'JSON'
{"nodes": {"root": {}}, "root": "root", "version": 7}
JSON
    FLAKE_LOCK_MAX_NODES=0 run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "positive integer"
}

@test "V9: negative FLAKE_LOCK_MAX_BYTES fails" {
    cat > "$TMP/flake.lock" <<'JSON'
{"nodes": {"root": {}}, "root": "root", "version": 7}
JSON
    FLAKE_LOCK_MAX_BYTES=-1 run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "positive integer"
}

# -- V10: top-N subtrees printed on node budget failure --

@test "V10: top subtrees printed on node count failure" {
    cat > "$TMP/flake.lock" <<'JSON'
{
  "nodes": {
    "root": {"inputs": {"big": "big", "small": "small"}},
    "big": {"inputs": {"dep1": "dep1", "dep2": "dep2"}},
    "dep1": {},
    "dep2": {},
    "small": {}
  },
  "root": "root",
  "version": 7
}
JSON
    FLAKE_LOCK_MAX_NODES=2 run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "big:"
}

# -- V1 edge: flake.lock exists in cwd with no arg --

@test "V1 edge: flake.lock in cwd with no arg is checked" {
    cd "$TMP"
    cat > "$TMP/flake.lock" <<'JSON'
{"nodes": {"root": {}}, "root": "root", "version": 7}
JSON
    run lefthook-nix-flake-lock-budget
    assert_success
}

# -- V9: hint shown on validation failure --

@test "V9: usage hint shown for bad FLAKE_LOCK_MAX_NODES" {
    cat > "$TMP/flake.lock" <<'JSON'
{"nodes": {"root": {}}, "root": "root", "version": 7}
JSON
    FLAKE_LOCK_MAX_NODES=abc run lefthook-nix-flake-lock-budget "$TMP/flake.lock"
    assert_failure
    assert_output --partial "hint:"
}
