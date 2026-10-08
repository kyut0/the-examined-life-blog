"""Expose a `recent_posts` list to every MkDocs template.

Why this exists
---------------
`docs/index.md` is Markdown and cannot run Jinja, so the home page's post list
has to come from a template partial. But Material's blog plugin only injects its
`posts` context variable into its OWN views (the timeline, archive and category
pages) -- a normal page like the home page never sees it.

The tempting workaround is to reach into the plugin instance from the template
(`config.plugins["material/blog"].blog.posts`). That works, but it depends on a
semi-private attribute chain that a theme upgrade can rename without warning.

This hook avoids that entirely. It reads the post source files and takes each
post's final URL from MkDocs' own `File` objects -- both public, documented
surfaces. The only thing it assumes about the blog plugin is where posts live on
disk, which is `blog_dir` in mkdocs.yml and unlikely to move silently.

Timing: `on_env` runs once, after `on_files`/`on_nav` (so the blog plugin has
already rewritten post URLs) and before any page renders (so there is no
page-ordering hazard -- unlike reading `page.title`, which is only populated
once that particular page renders).
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import yaml

# Posts live under `<blog_dir>/posts/`; blog_dir comes from mkdocs.yml.
POSTS_SUBDIR = "posts"

# Number of posts handed to the template. The template decides how many to show.
LIMIT = 20

_FRONT_MATTER = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_H1 = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)


def _read_source(abs_path: str) -> tuple[dict, str]:
    """Return (front matter dict, markdown body) for a post source file."""
    text = Path(abs_path).read_text(encoding="utf-8")

    match = _FRONT_MATTER.match(text)
    if not match:
        return {}, text

    try:
        meta = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError:
        meta = {}

    if not isinstance(meta, dict):
        meta = {}

    return meta, text[match.end():]


def _created_date(meta: dict) -> Any:
    """Pull the creation date out of front matter.

    Material accepts both `date: 2026-08-24` and the nested
    `date:\n  created: 2026-08-24` form, so handle either.
    """
    raw = meta.get("date")

    if isinstance(raw, dict):
        raw = raw.get("created")

    return raw


def _title(meta: dict, body: str, fallback: str) -> str:
    """Prefer an explicit front-matter title, then the first H1, then the slug."""
    explicit = meta.get("title")
    if isinstance(explicit, str) and explicit.strip():
        return explicit.strip()

    heading = _H1.search(body)
    if heading:
        return heading.group(1).strip()

    return fallback


def _categories(meta: dict) -> list[str]:
    raw = meta.get("categories") or []
    if isinstance(raw, str):
        raw = [raw]
    return [str(c) for c in raw if str(c).strip()]


def on_env(env, config, files, **kwargs):
    """Build the post list once and expose it as a global to all templates."""
    blog_dir = "blog"

    # Read blog_dir off the blog plugin's *config* (public, schema-backed) rather
    # than its internals, so a renamed blog_dir keeps working.
    plugin = config.plugins.get("material/blog")
    if plugin is not None:
        blog_dir = plugin.config.get("blog_dir", blog_dir) or blog_dir

    prefix = f"{blog_dir.strip('/')}/{POSTS_SUBDIR}/"

    posts = []
    for file in files.documentation_pages():
        src = file.src_uri  # always POSIX-separated, unlike src_path
        if not src.startswith(prefix):
            continue
        if src.endswith("/index.md"):
            continue

        meta, body = _read_source(file.abs_src_path)

        # A post with no date is a draft as far as this list is concerned;
        # Material requires `date` on real posts anyway.
        created = _created_date(meta)
        if created is None:
            continue

        posts.append(
            {
                "title": _title(meta, body, Path(src).stem),
                "url": file.url,
                "date": created,
                "categories": _categories(meta),
            }
        )

    # Newest first. `date` may be a date or a datetime depending on how the
    # front matter was written, so normalise before comparing.
    def _sort_key(post):
        value = post["date"]
        return getattr(value, "toordinal", lambda: 0)()

    posts.sort(key=_sort_key, reverse=True)

    env.globals["recent_posts"] = posts[:LIMIT]
