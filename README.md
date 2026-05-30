# wtf

`wtf` explains why your last shell command failed and what to do next.

It captures:

- the command text
- its exit status
- the command's stderr (cleaned of terminal control sequences)

Then it sends that context to an installed agent CLI (**opencode**, **GitHub Copilot CLI**, or **Claude Code**) and prints a short plain-English answer.

## Inspiration and approach differences

This project is directly inspired by:

- https://codeberg.org/ryanbastic/wtf
- https://github.com/bendusz/wtf
- Original post: https://www.linkedin.com/feed/update/urn:li:activity:7464652533538631680/

The three versions share the same core idea (explain terminal failures quickly), but take different approaches:

| Version | Core approach |
| --- | --- |
| **This repo (`simonpainter/wtf`)** | Captures command context from shell hooks and captured stderr without re-running the command, then routes to one of multiple CLIs (`opencode`, `copilot`, `claude`). Focus is portable shell-only implementation, multi-agent support, and predictable "explain only" behavior. |
| **`ryanbastic/wtf` (Codeberg)** | Minimal, Claude-first implementation of the original "type `wtf` after failure" flow. Emphasizes simplicity and fast setup around captured last-command context. |
| **`bendusz/wtf` (GitHub)** | Safety-gated re-run model: it can re-execute the last command (allowlist + prompts) to capture fresh output, and optionally propose/run a fix (`--fix`) after confirmation. Emphasizes controlled automation and remediation workflow. |

## Example

```sh
$ docker run myimage
docker: Error response from daemon: No such image: myimage:latest
$ wtf
Asking opencode…
Docker can't find a local image called "myimage" because it hasn't been built or pulled yet. Build it with `docker build -t myimage .` from the directory with your Dockerfile, or `docker pull myimage` if it exists in a registry.
```

## Requirements

- macOS or Linux
- zsh or bash
- one agent CLI on your `PATH`: `opencode`, `copilot`, or `claude`
- standard utilities: `sed`, `tail`, `tr`, and `stat` (or compatible equivalents)

## Install

### Recommended

```sh
./install.sh
```

This does the following:

1. Copies `wtf.sh` to `~/.wtf.sh`
2. Ensures `~/.zshrc` exists and adds:
   ```sh
   [ -f ~/.wtf.sh ] && . ~/.wtf.sh
   ```
3. Adds the same line to `~/.bashrc` only if `.bashrc` already exists

Open a new shell (or run `. ~/.wtf.sh`) after installing.

### Manual

```sh
cp wtf.sh ~/.wtf.sh
echo '[ -f ~/.wtf.sh ] && . ~/.wtf.sh' >> ~/.zshrc
```

## Usage

Run any command as usual. If it fails or behaves unexpectedly, run:

```sh
wtf
```

If no prior command has been captured yet, `wtf` exits with:

```text
Nothing to explain yet — run a command first, then type wtf.
```

## Configuration

All configuration is via environment variables.

| Variable | Default | Description |
| --- | --- | --- |
| `WTF_AGENT` | auto-detect | Force one of `opencode`, `copilot`, or `claude`. If set to an unavailable CLI, auto-detection is used instead. |
| `WTF_TIMEOUT` | `90` | Seconds to allow the agent command to run. Set to `0` to disable. |

### Agent selection order

If `WTF_AGENT` is not set, agent detection order is:

1. `opencode`
2. `copilot`
3. `claude`

If you have multiple agent CLIs installed, you can switch explicitly. For example, to force GitHub Copilot CLI:

```sh
export WTF_AGENT="copilot"
```

### Timeout behavior

- Timeout is enforced only when `timeout` or `gtimeout` is installed.
- On macOS, `gtimeout` is usually available via GNU coreutils:
  ```sh
  brew install coreutils
  ```
- If timeout is reached, `wtf` exits with a timeout message.

## How it works

1. `wtf.sh` tees shell stderr into a per-shell temp file (`/tmp` or `$TMPDIR`).
2. A shell hook captures command start (command text + stderr byte offset).
3. Another hook captures command end (exit status + stderr slice for that command).
4. `wtf` builds a structured prompt and invokes one CLI command:
   - `opencode run`
   - `copilot -p ... -s`
   - `claude -p`
5. Output is cleaned and printed.

`wtf` does **not** rerun your original command.

## Shell-specific notes

- **zsh**: uses `preexec` and `precmd` hooks.
- **bash**: uses a `DEBUG` trap and `PROMPT_COMMAND`.
- A priming guard avoids capturing noise from initial shell startup.
- `wtf` itself is excluded from capture so it always explains the last real command.

## Tests

A small shell test suite is included at:

```sh
./tests/test.sh
```

Current coverage includes:

- agent selection (forced and auto-detect order)
- no-prior-command behavior
- install script behavior and idempotency

## Uninstall

```sh
rm ~/.wtf.sh
```

Then remove this line from your shell rc files:

```sh
[ -f ~/.wtf.sh ] && . ~/.wtf.sh
```
