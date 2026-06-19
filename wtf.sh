# wtf — when a command fails, type `wtf` for a one-paragraph explanation of what
# went wrong and how to fix it. It reads the last command, its captured stderr,
# and its exit status, then routes them to whichever agent CLI is installed:
# Claude Code (`claude`), GitHub Copilot CLI (`copilot`), or `opencode`.
#
# Pure shell, no binary. Works in zsh and bash on macOS and Linux. Install by
# sourcing from your ~/.zshrc or ~/.bashrc:
#
#     source ~/.wtf.sh
#
# Config (all optional, via environment):
#   WTF_AGENT    force one of: claude | copilot | opencode | codex (else auto-detect)
#   WTF_TIMEOUT  seconds to wait for the agent (default 90; 0 disables; only
#                applied if `timeout`/`gtimeout` is available)

# --- per-session state -------------------------------------------------------

_wtf_raw="${TMPDIR:-/tmp}/wtf.$$.stderr"
: > "$_wtf_raw" 2>/dev/null

# Permanently tee this shell's stderr to the raw file while still displaying it.
exec 2> >(tee -a "$_wtf_raw" >&2)

_WTF_LIVE_CMD=""   # written by preexec/DEBUG (may become "wtf")
_WTF_LIVE_OFF=0
_WTF_CMD=""        # snapshot written by precmd; what `wtf` actually reads
_WTF_STATUS=""
_WTF_OUTPUT=""
_WTF_PRIMED=""     # bash runs the DEBUG trap while sourcing; ignore until primed

# --- helpers -----------------------------------------------------------------

_wtf_filesize() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || wc -c < "$1" 2>/dev/null || echo 0
}

# Strip ANSI escape sequences and stray control bytes (interactive shells draw
# prompts to stderr, which our tee captures). Reads stdin, writes stdout.
_wtf_clean() {
  local esc; esc=$(printf '\033')
  local bel; bel=$(printf '\007')
  LC_ALL=C sed -e "s/${esc}\[[0-9;?]*[ -/]*[@-~]//g" \
               -e "s/${esc}\][^${bel}]*${bel}//g" 2>/dev/null \
    | LC_ALL=C tr -d "$(printf '\001-\010\013\014\016-\037\177')"
}

# Run the agent, optionally under a timeout if one is available.
_wtf_run() {
  local to="${WTF_TIMEOUT:-90}"
  if [ "$to" != "0" ] && command -v timeout >/dev/null 2>&1; then
    timeout "$to" "$@"
  elif [ "$to" != "0" ] && command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$to" "$@"
  else
    "$@"
  fi
}

# Echo the agent to use, or return 1 if none found.
_wtf_pick() {
  case "$WTF_AGENT" in
    claude|copilot|opencode|codex|apfel)
      command -v "$WTF_AGENT" >/dev/null 2>&1 && { printf '%s' "$WTF_AGENT"; return 0; } ;;
  esac
  local a
  for a in opencode copilot claude codex apfel; do      # detection order; edit to taste
    command -v "$a" >/dev/null 2>&1 && { printf '%s' "$a"; return 0; }
  done
  return 1
}

# --- capture hooks -----------------------------------------------------------

_wtf_preexec() {            # before a command runs
  _WTF_LIVE_CMD="$1"
  _WTF_LIVE_OFF="$(_wtf_filesize "$_wtf_raw")"
}

_wtf_precmd() {             # after it finishes, before the next prompt
  local st=$?
  if [ -z "$_WTF_PRIMED" ]; then   # discard whatever sourcing left behind
    _WTF_PRIMED=1
    _WTF_LIVE_CMD=""; _WTF_CMD=""; _WTF_STATUS=""; _WTF_OUTPUT=""
    return
  fi
  case "$_WTF_LIVE_CMD" in  # don't let `wtf` overwrite its own evidence
    ''|wtf|wtf\ *) return ;;
  esac
  _WTF_CMD="$_WTF_LIVE_CMD"
  _WTF_STATUS="$st"
  _WTF_OUTPUT=$(tail -c "+$(( _WTF_LIVE_OFF + 1 ))" "$_wtf_raw" 2>/dev/null \
                | _wtf_clean | tail -n 200 | tail -c 6000)
}

# --- the command -------------------------------------------------------------

wtf() {
  if [ -z "$_WTF_CMD" ]; then
    echo "Nothing to explain yet — run a command first, then type wtf." >&2
    return 1
  fi
  local agent
  agent=$(_wtf_pick) || {
    echo "No supported agent CLI found (claude, copilot, opencode, codex or apfel)." >&2
    echo "Install one, or set WTF_AGENT to force a choice." >&2
    return 1
  }

  local prompt
  prompt=$(printf '%s\n' \
    "You are a command-line troubleshooting assistant. A shell command just ran and appears to have failed. Explain in ONE short paragraph of plain prose — no preamble, no code fences, no bullet lists — what went wrong and how to fix it. Be specific and practical. Do not run any commands or modify any files; only explain. If the command actually succeeded (exit status 0 and no real error), just say so in one line." \
    "" \
    "Command: $_WTF_CMD" \
    "Exit status: ${_WTF_STATUS:-unknown}" \
    "Error output:" \
    "${_WTF_OUTPUT:-(none captured)}")

  echo "Asking ${agent}…" >&2

  local answer
  case "$agent" in
    claude)   answer=$(_wtf_run claude -p "$prompt" 2>&1) ;;
    copilot)  answer=$(_wtf_run copilot -p "$prompt" -s 2>&1) ;;
    opencode) answer=$(_wtf_run opencode run "$prompt" 2>&1) ;;
    codex)    answer=$(_wtf_run codex "$prompt" 2>&1) ;;
    apfel)    answer=$(_wtf_run apfel "$prompt" 2>&1) ;;
  esac
  local rc=$?

  if [ "$rc" -eq 124 ]; then
    echo "${agent} timed out. Set WTF_TIMEOUT (seconds; 0 disables)." >&2
    return 1
  fi
  printf '%s\n' "$answer" | _wtf_clean
}

# --- wire up hooks for the current shell -------------------------------------

if [ -n "$ZSH_VERSION" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null
  if command -v add-zsh-hook >/dev/null 2>&1; then
    add-zsh-hook preexec _wtf_preexec
    add-zsh-hook precmd  _wtf_precmd
    add-zsh-hook zshexit '_wtf_cleanup'
  else
    preexec_functions+=(_wtf_preexec)
    precmd_functions+=(_wtf_precmd)
  fi
elif [ -n "$BASH_VERSION" ]; then
  _wtf_debug() {
    [ -n "$COMP_LINE" ] && return                       # ignore tab-completion
    [ "$BASH_COMMAND" = "$PROMPT_COMMAND" ] && return    # ignore the prompt hook
    _wtf_preexec "$BASH_COMMAND"
  }
  trap '_wtf_debug' DEBUG
  case "$PROMPT_COMMAND" in
    *_wtf_precmd*) ;;
    '') PROMPT_COMMAND="_wtf_precmd" ;;
    *)  PROMPT_COMMAND="_wtf_precmd;${PROMPT_COMMAND}" ;;
  esac
  trap '_wtf_cleanup' EXIT
fi

_wtf_cleanup() { rm -f "$_wtf_raw" 2>/dev/null; }
