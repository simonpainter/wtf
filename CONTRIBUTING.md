# Contributing

Thanks for your interest in improving `wtf`.

## Getting started

1. Fork the repository and create a feature branch.
2. Make focused changes with clear commit messages.
3. Run the test suite:

```sh
./tests/test.sh
```

4. Open a pull request with context, rationale, and testing notes.

## Contribution guidelines

- Keep changes small and purpose-specific.
- Preserve shell portability for macOS/Linux and bash/zsh behavior.
- Prefer explicit, readable shell over clever one-liners.
- Update docs when behavior, CLI usage, or configuration changes.
- Avoid introducing heavy dependencies for simple tasks.

## Reporting bugs

Please include:

- shell (`bash` or `zsh`) and OS version
- failing command and observed output
- relevant `WTF_*` environment variables
- steps to reproduce
