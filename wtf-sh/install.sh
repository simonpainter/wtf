#!/bin/sh
# Installs wtf: copies wtf.sh to ~/.wtf.sh and wires it into your shell rc.
set -e

src="$(cd "$(dirname "$0")" && pwd)/wtf.sh"
dest="$HOME/.wtf.sh"
cp "$src" "$dest"

line='[ -f ~/.wtf.sh ] && . ~/.wtf.sh'

add_to() {
  rc="$1"
  [ -e "$rc" ] || { [ "$2" = "create" ] && : > "$rc" || return 0; }
  if ! grep -q '\.wtf\.sh' "$rc" 2>/dev/null; then
    printf '\n# wtf\n%s\n' "$line" >> "$rc"
    echo "  wired into $rc"
  fi
}

add_to "$HOME/.zshrc" create     # macOS default shell
add_to "$HOME/.bashrc"           # only if it already exists

echo "Installed $dest. Open a new shell, or run: . ~/.wtf.sh"
