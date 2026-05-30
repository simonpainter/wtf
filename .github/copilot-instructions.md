# Copilot instructions for this repository

## Project overview

This repository contains a portable shell utility (`wtf.sh`) that explains failed terminal commands by sending captured command context to an installed agent CLI.

Core goals:

- keep behavior predictable and explain-only (no command re-execution)
- support both `zsh` and `bash`
- preserve portability across macOS and Linux
- keep dependencies minimal (POSIX shell utilities where practical)

## Implementation guidelines

- Prefer shell-compatible patterns that work in both `bash` and `zsh` contexts.
- Keep stderr-capture and hook logic deterministic and side-effect free.
- Avoid adding non-essential dependencies, especially for core runtime paths.
- Preserve existing agent selection behavior and timeout handling semantics.
- Keep user-facing output concise and plain text.

## Testing expectations

- Update `tests/test.sh` when behavior changes.
- Keep tests focused on observable behavior (selection order, guardrails, install behavior, etc.).
- Ensure install behavior remains idempotent.

## Documentation expectations

- If behavior or configuration changes, update `README.md`.
- Keep docs consistent with real command names and environment variables.
