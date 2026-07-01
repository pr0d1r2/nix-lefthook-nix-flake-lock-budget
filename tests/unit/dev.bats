#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TMP="$BATS_TEST_TMPDIR"

    mkdir -p "$TMP/repo/.git"

    mkdir -p "$TMP/bin"
    cat > "$TMP/bin/lefthook" <<'SH'
#!/usr/bin/env bash
echo "lefthook $*" >> "$TMP/lefthook.log"
SH
    chmod +x "$TMP/bin/lefthook"
    export PATH="$TMP/bin:$PATH"
}

teardown() {
    rm -rf "$TMP"
}

@test "sets BATS_LIB_PATH from placeholder" {
    unset BATS_LIB_PATH
    # shellcheck disable=SC2034
    BATS_LIB_PATH=""
    eval "$(sed 's|@BATS_LIB_PATH@|/test/lib|' dev.sh)"
    assert_equal "$BATS_LIB_PATH" "/test/lib/share/bats"
}

@test "runs lefthook install when hooks are missing" {
    cd "$TMP/repo"
    export TMP
    eval "$(sed 's|@BATS_LIB_PATH@|/test/lib|' "$OLDPWD/dev.sh")"
    assert [ -f "$TMP/lefthook.log" ]
    run cat "$TMP/lefthook.log"
    assert_output --partial "lefthook install"
}

@test "skips lefthook install when hooks exist" {
    cd "$TMP/repo"
    mkdir -p .git/hooks
    touch .git/hooks/pre-commit
    export TMP
    eval "$(sed 's|@BATS_LIB_PATH@|/test/lib|' "$OLDPWD/dev.sh")"
    assert [ ! -f "$TMP/lefthook.log" ]
}
