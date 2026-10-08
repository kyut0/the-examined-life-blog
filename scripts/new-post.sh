#!/usr/bin/env bash
#
# Scaffold a new DRAFT post.
#
#   ./scripts/new-post.sh "How to Open and Invest in a Roth IRA"
#
# The new file is created with `draft: true`, so it renders in `mkdocs serve`
# but is excluded from `mkdocs build` -- you can write and preview it in place
# without any risk of it going live. Run scripts/publish-post.sh when ready.
#
# Naming: drafts get a `draft_` prefix rather than a number. The NN_ prefix on
# published posts records publication order, and that is not knowable at
# creation time -- you might publish your third draft first. publish-post.sh
# assigns the number.
#
# Note the NN_ prefix is purely a filesystem convenience: the blog plugin sorts
# the timeline by descending `date`, and derives the URL slug from the H1. The
# filename affects neither.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/templates/post.md"
POSTS_DIR="$ROOT/docs/blog/posts"

if [ $# -lt 1 ]; then
  echo "usage: $(basename "$0") \"Post Title\"" >&2
  exit 64
fi

TITLE="$*"

if [ ! -f "$TEMPLATE" ]; then
  echo "error: template not found at $TEMPLATE" >&2
  exit 66
fi

SLUG="$(printf '%s' "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"

DEST="$POSTS_DIR/draft_${SLUG}.md"

if [ -e "$DEST" ]; then
  echo "error: $DEST already exists" >&2
  exit 73
fi

# The date is a placeholder. A draft still needs a *valid* date -- the blog
# plugin validates front matter before it checks whether a post is excluded, so
# `date: TBD` fails the build. publish-post.sh re-stamps this to the real
# publication date, which is why it does not matter that this goes stale.
TODAY="$(date +%Y-%m-%d)"

mkdir -p "$POSTS_DIR"
sed -e "s/DATE_PLACEHOLDER/$TODAY/" \
    -e "s/TITLE_PLACEHOLDER/$(printf '%s' "$TITLE" | sed 's/[&/\]/\\&/g')/" \
    "$TEMPLATE" > "$DEST"

echo "Created $DEST"
echo "  title: $TITLE"
echo "  draft: true  (renders in \`mkdocs serve\`, excluded from \`mkdocs build\`)"
echo "  date:  $TODAY  (placeholder — re-stamped on publish)"
echo
echo "Preview:  mkdocs serve"
echo "Publish:  ./scripts/publish-post.sh $(basename "$DEST")"
