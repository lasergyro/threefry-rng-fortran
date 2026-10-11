#!/usr/bin/env bash
# Links this directory's pre-commit hooks into .git/hooks/pre-commit.d/:
#   60-format  format staged Fortran and Python, and re-stage them
#   70-lint    stop the commit on lint findings
# They are run in name order by a dispatcher, .git/hooks/pre-commit, which is
# installed too if there is no pre-commit hook yet. An existing hook of another
# kind is left alone, with a note on how to call the two from it.
#
# Usage: .githooks/install.sh     (once per clone; needs pixi)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hooks="$(git -C "$here" rev-parse --path-format=absolute --git-path hooks)"
mkdir -p "$hooks/pre-commit.d"
ln -sfn "$here/format" "$hooks/pre-commit.d/60-format"
ln -sfn "$here/lint" "$hooks/pre-commit.d/70-lint"

if [ ! -e "$hooks/pre-commit" ]; then
  cat > "$hooks/pre-commit" <<'EOF'
#!/usr/bin/env bash
# Git pre-commit dispatcher: runs every executable in <hooks>/pre-commit.d/ in name order,
# stopping at the first failure.
set -euo pipefail

dir="$(git rev-parse --path-format=absolute --git-path hooks)/pre-commit.d"
[ -d "$dir" ] || exit 0

for hook in "$dir"/*; do
  [ -x "$hook" ] || continue
  "$hook" "$@"
done
EOF
  chmod +x "$hooks/pre-commit"
elif ! grep -q 'pre-commit.d' "$hooks/pre-commit"; then
  echo "install.sh: $hooks/pre-commit exists and doesn't run pre-commit.d/;" >&2
  echo "  call $hooks/pre-commit.d/60-format and 70-lint from it yourself." >&2
fi
echo "linked format and lint into $hooks/pre-commit.d"
