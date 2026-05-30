# wtf

When a command fails, type `wtf` and get a one-paragraph explanation of what
went wrong and how to fix it. It grabs the last command, its error output, and
its exit status, then sends them to whichever agent CLI you have installed —
**Claude Code**, **GitHub Copilot CLI**, or **opencode** — and prints the answer.

```
$ docker run myimage
docker: Error response from daemon: No such image: myimage:latest
$ wtf
Asking claude…
Docker can't find a local image called "myimage" because it hasn't been built
or pulled yet. Build it with `docker build -t myimage .` from the directory with
your Dockerfile, or `docker pull myimage` if it lives in a registry.
```

A shell-only reimplementation of [ryanbastic/wtf](https://codeberg.org/ryanbastic/wtf),
routed through an agent CLI instead of the Claude API, so it uses your existing
auth and needs no API key. One file, no binary, no build step.

## Requirements

- zsh or bash, on macOS or Linux
- One of these on your `PATH`: `claude`, `copilot`, or `opencode`
- Standard tools that are already present: `sed`, `tail`, `tr`, `stat`

## Install

```sh
./install.sh
```

That copies `wtf.sh` to `~/.wtf.sh` and adds a source line to `~/.zshrc` (and
`~/.bashrc` if it exists). Then open a new shell.

Or do it by hand:

```sh
cp wtf.sh ~/.wtf.sh
echo '[ -f ~/.wtf.sh ] && . ~/.wtf.sh' >> ~/.zshrc   # or ~/.bashrc
```

## Usage

Run a command, and if it misbehaves, type `wtf`.

## Configuration

Optional environment variables:

- `WTF_AGENT` — force a specific agent (`claude`, `copilot`, or `opencode`).
  Otherwise it auto-detects in the order opencode → copilot → claude; edit the
  `for a in …` line in `wtf.sh` to change priority.
- `WTF_TIMEOUT` — seconds to wait for the agent (default 90; `0` disables).
  Only applied if `timeout` or `gtimeout` is on the system; macOS has neither
  by default, so it runs without a timeout there unless you've installed
  coreutils (`brew install coreutils` provides `gtimeout`).

## How it works

- The shim permanently tees your shell's stderr to a per-session temp file.
- A `preexec` hook (zsh) or `DEBUG` trap (bash) records each command and the
  byte offset where its stderr begins. A `precmd`/`PROMPT_COMMAND` hook then
  slices from that offset to capture only that command's error output, plus its
  exit status. The snapshot is skipped when the command is `wtf` itself, so it
  always reflects the last *real* command.
- `wtf` reads the snapshot, strips terminal escape sequences, builds a short
  prompt, finds an installed agent, and runs it once non-interactively
  (`claude -p`, `copilot -p … -s`, or `opencode run …`).

It never re-runs the failed command.

### Per-shell notes

- **bash** runs the `DEBUG` trap while the file is still sourcing, so the first
  prompt cycle is used to discard anything captured during load (the `_WTF_PRIMED`
  guard). zsh doesn't need this but the guard is harmless there.
- The capture slices stderr *between* the pre- and post-command hooks, so prompt
  redraw escape codes (which zsh writes to stderr) fall outside the slice; any
  that do leak are stripped by the cleaner.

## Uninstall

```sh
rm ~/.wtf.sh
```

Then remove the `wtf.sh` source line from your `~/.zshrc` / `~/.bashrc`.
