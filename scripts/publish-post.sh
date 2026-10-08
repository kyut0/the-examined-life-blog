#!/usr/bin/env bash
#
# Promote a draft to a published post.
#
#   ./scripts/publish-post.sh draft_how_to_open_and_invest_in_roth_ira.md
#   ./scripts/publish-post.sh roth          # a FILENAME fragment is fine
#
# The argument matches the draft's filename, not the post's H1 title. Those
# usually look alike, because new-post.sh derives the filename from the title
# you gave it -- but rewriting the H1 later does not rename the file.
#
# Does three things, all of which have to happen together:
#
#   1. Re-stamps `date:` to today. A draft's date is set at creation and goes
#      stale while you write; the date is what orders the timeline AND what
#      lands in the post's URL (post_url_format is "{date}/{slug}"), so it must
#      be the real publication date.
#   2. Removes the `draft: true` line, which is what excludes it from the build.
#   3. Renames draft_<slug>.md -> NN_<slug>.md, continuing the numbering. The
#      number records publication order, which is only knowable now.
#
# Use `git mv` when the file is tracked so history follows the rename.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTS_DIR="$ROOT/docs/blog/posts"

if [ $# -ne 1 ]; then
  echo "usage: $(basename "$0") <draft-filename-or-filename-fragment>" >&2
  echo "       matches against draft_*.md filenames, not post titles" >&2
  exit 64
fi

NEEDLE="$1"

# Resolve the draft: exact filename first, then a unique partial match.
if [ -f "$POSTS_DIR/$NEEDLE" ]; then
  SRC="$POSTS_DIR/$NEEDLE"
else
  # -F: match the needle literally. Without it grep treats the argument as a
  # regex, so a fragment containing . * [ or ^ would match something unintended.
  MATCHES=$(find "$POSTS_DIR" -maxdepth 1 -name 'draft_*.md' -exec basename {} \; \
            | grep -iF -- "$NEEDLE" || true)
  COUNT=$(printf '%s' "$MATCHES" | grep -c . || true)

  if [ "$COUNT" -eq 0 ]; then
    echo "error: no draft matching '$NEEDLE' in $POSTS_DIR" >&2
    echo "drafts available:" >&2
    find "$POSTS_DIR" -maxdepth 1 -name 'draft_*.md' -exec basename {} \; | sed 's/^/  /' >&2
    exit 66
  fi
  if [ "$COUNT" -gt 1 ]; then
    echo "error: '$NEEDLE' matches more than one draft:" >&2
    printf '%s\n' "$MATCHES" | sed 's/^/  /' >&2
    exit 65
  fi
  SRC="$POSTS_DIR/$MATCHES"
fi

if ! grep -qE '^draft:[[:space:]]*true[[:space:]]*$' "$SRC"; then
  echo "error: $(basename "$SRC") is not marked 'draft: true' — already published?" >&2
  exit 65
fi

if ! grep -qF '<!-- more -->' "$SRC"; then
  echo "error: $(basename "$SRC") has no '<!-- more -->' separator." >&2
  echo "       mkdocs.yml sets post_excerpt: required, so this would fail the build." >&2
  exit 65
fi

TODAY="$(date +%Y-%m-%d)"

# Next NN, continuing the existing numbering.
LAST="$(find "$POSTS_DIR" -maxdepth 1 -name '*.md' -exec basename {} \; \
        | sed -nE 's/^([0-9]+)_.*\.md$/\1/p' | sort -n | tail -1)"
NEXT="$(printf '%02d' $(( 10#${LAST:-0} + 1 )))"

BASE="$(basename "$SRC")"
SLUG="${BASE#draft_}"
DEST="$POSTS_DIR/${NEXT}_${SLUG}"

if [ -e "$DEST" ]; then
  echo "error: $DEST already exists" >&2
  exit 73
fi

OLD_DATE="$(sed -nE 's/^date:[[:space:]]*(.*)$/\1/p' "$SRC" | head -1)"

# Rewrite front matter: new date, no draft line. Written to a temp file and
# moved, rather than `sed -i`, because BSD and GNU sed disagree on -i syntax.
TMP="$(mktemp)"
sed -e "s/^date:[[:space:]]*.*$/date: $TODAY/" \
    -e "/^draft:[[:space:]]*true[[:space:]]*$/d" \
    "$SRC" > "$TMP"
mv "$TMP" "$SRC"

if git -C "$ROOT" ls-files --error-unmatch "$SRC" >/dev/null 2>&1; then
  git -C "$ROOT" mv "$SRC" "$DEST"
else
  mv "$SRC" "$DEST"
fi

echo "Published $(basename "$DEST")"
echo "  date:  ${OLD_DATE:-?} -> $TODAY"
echo "  draft: removed"
echo "  file:  $BASE -> $(basename "$DEST")"
echo
echo "Verify:  mkdocs build --strict"
echo "Ship:    git add -A && git commit && git push"
