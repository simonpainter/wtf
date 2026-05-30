#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WTF_SH="$ROOT/wtf.sh"
INSTALL_SH="$ROOT/install.sh"

pass_count=0

pass() {
  pass_count=$((pass_count + 1))
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="$3"
  [ "$actual" = "$expected" ] || fail "$msg (expected '$expected', got '$actual')"
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local msg="$3"
  grep -Fq "$needle" "$file" || fail "$msg"
}

run_in_clean_env() {
  local code="$1"
  bash -lc "set -eo pipefail; source '$WTF_SH'; $code"
}

test_pick_honors_forced_agent() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  printf '#!/bin/sh\nexit 0\n' > "$tmpdir/claude"
  chmod +x "$tmpdir/claude"

  local out
  out="$(PATH="$tmpdir:$PATH" WTF_AGENT=claude run_in_clean_env '_wtf_pick')"
  assert_eq "$out" "claude" "WTF_AGENT should be honored when binary exists"
  pass "pick_honors_forced_agent"
}

test_pick_prefers_opencode_then_copilot_then_claude() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  printf '#!/bin/sh\nexit 0\n' > "$tmpdir/claude"
  printf '#!/bin/sh\nexit 0\n' > "$tmpdir/copilot"
  printf '#!/bin/sh\nexit 0\n' > "$tmpdir/opencode"
  chmod +x "$tmpdir/claude" "$tmpdir/copilot" "$tmpdir/opencode"

  local out
  out="$(PATH="$tmpdir:$PATH" run_in_clean_env '_wtf_pick')"
  assert_eq "$out" "opencode" "auto-detect should prioritize opencode"
  pass "pick_prefers_order"
}

test_wtf_requires_prior_command() {
  local tmpfile
  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' RETURN
  if run_in_clean_env '_WTF_CMD=""; wtf' >"$tmpfile" 2>&1; then
    fail "wtf should fail when no prior command exists"
  fi
  assert_file_contains "$tmpfile" "Nothing to explain yet" "wtf should explain missing context"
  pass "wtf_requires_prior_command"
}

test_install_copies_and_wires_zshrc_idempotently() {
  local tmphome
  tmphome="$(mktemp -d)"
  trap 'rm -rf "$tmphome"' RETURN

  HOME="$tmphome" sh "$INSTALL_SH" >/dev/null
  [ -f "$tmphome/.wtf.sh" ] || fail "install should copy ~/.wtf.sh"
  [ -f "$tmphome/.zshrc" ] || fail "install should create ~/.zshrc"
  [ ! -f "$tmphome/.bashrc" ] || fail "install should not create ~/.bashrc"
  assert_file_contains "$tmphome/.zshrc" "[ -f ~/.wtf.sh ] && . ~/.wtf.sh" "install should wire source line"

  HOME="$tmphome" sh "$INSTALL_SH" >/dev/null
  local count
  count="$(grep -Fc "[ -f ~/.wtf.sh ] && . ~/.wtf.sh" "$tmphome/.zshrc")"
  assert_eq "$count" "1" "install should not duplicate source line"
  pass "install_is_idempotent"
}

test_pick_honors_forced_agent
test_pick_prefers_opencode_then_copilot_then_claude
test_wtf_requires_prior_command
test_install_copies_and_wires_zshrc_idempotently

printf '\n%s tests passed\n' "$pass_count"
