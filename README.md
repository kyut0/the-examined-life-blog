# The Examined Life — Blog

The code behind my personal blog, **[blog.the-examined-life.com](https://blog.the-examined-life.com)**.

> **This repository is the machinery, not the writing.** It holds the site
> config, theme overrides, publishing scripts and build setup. The posts
> themselves live on the blog — go read them there. The one post in
> `docs/blog/posts/` is an example that exists so a fresh clone builds and
> renders something.

The site is a Python static-site build: Markdown in, static HTML out, deployed
free on Vercel.

---

## Tech Stack & Architecture

| Component | Platform / Tool | Description |
| :--- | :--- | :--- |
| **Domain & DNS** | [Cloudflare](https://cloudflare.com) | Manages nameservers; handles the `blog` subdomain. |
| **Hosting Platform** | [Vercel](https://vercel.com) | Compiles the code from GitHub and serves the static HTML files for free. |
| **Site Generator** | [MkDocs](https://mkdocs.org) | Compiles Markdown text files into responsive HTML web pages. |
| **Theme / Engine** | [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) | Provides native blogging timelines, dark mode, and UI overrides. |
| **Environment Manager** | [Poetry](https://python-poetry.org) | Handles deterministic Python dependency tracking via `pyproject.toml`. |
| **Comments Engine** | [Cusdis](https://cusdis.com) | A privacy-first, lightweight discussion block for anonymous comments. |
| **Newsletter / Email** | [Kit](https://kit.com) (formerly ConvertKit) | Collects email subscribers via an embedded form on each post. |

---

## Key File Map

```text
├── pyproject.toml                # Poetry project metadata & dependencies
├── vercel.json                   # Vercel cloud environment build script instructions
├── mkdocs.yml                    # Master site config, footer copyright, timeline rules, & navigation
├── scripts/
│   ├── new-post.sh               # ⭐ Scaffold a new DRAFT post
│   └── publish-post.sh           # ⭐ Promote a draft: re-date, drop draft flag, renumber
├── templates/
│   └── post.md                   # ⚠️ Blank post template — keep OUTSIDE docs/ (see below)
├── hooks/
│   └── recent_posts.py           # Builds the `recent_posts` list for the home page
└── docs/                         # Web site content source directory
    ├── index.md                  # Main homepage layout file
    ├── blog/                     # Blog plugin home environment directory
    │   ├── .authors.yml          # Author profile definitions
    │   ├── index.md              # Timeline landing page header text
    │   └── posts/                # ⚠️ Reverse-chronological articles go HERE
    │       ├── 01_*.md           # Published posts (NN_ = publication order)
    │       └── draft_*.md        # Drafts — draft: true, excluded from build
    ├── assets/                   # Images, favicon, & custom stylesheet
    │   └── custom.css            # Footer palette overrides & newsletter form styling
    └── overrides/                # Theme template overrides (see theme.custom_dir)
        └── partials/
            ├── header.html       # Full-bleed banner image above the top nav
            ├── comments.html     # Post footer: Cusdis thread + newsletter — blog posts only
            ├── newsletters.html  # Kit email signup form (included by comments.html)
            └── recent-posts.html # Home page post list (included by comments.html)
```

Override filenames are **not** arbitrary: Material only picks up a partial whose name matches one of its own templates (`header.html`, `comments.html`, `footer.html`, …). `newsletters.html` is a custom name, so it renders only because `comments.html` explicitly includes it. Dropping a new `.html` into `partials/` does nothing on its own.

---

## Local Development Workflow

To work on the blog locally, add posts, or test template adjustments:

1. **Activate the Environment:**
   ```bash
   poetry shell
   ```

2. **Launch the Local Dev Server:**
   ```bash
   mkdocs serve
   ```
   Open your browser and navigate to `http://127.0.0.1:8000`. The server features hot-reloading; saving any Markdown file will instantly refresh your browser page view.

---

## Writing a New Post

Two commands, and everything in between is just writing.

```bash
./scripts/new-post.sh "Title of Your Article"   # creates a draft
mkdocs serve                                    # preview it at 127.0.0.1:8000
./scripts/publish-post.sh roth                  # go live (filename fragment)
```

**Drafts live in `docs/blog/posts/` alongside everything else**, marked `draft: true`. That flag means the post renders in `mkdocs serve` but is excluded from `mkdocs build` — so you write and preview it in its real location, with working images and real styling, at zero risk of it going live. No draft branches, no separate folder.

`publish-post.sh` does the three things that have to happen together:

| Step | Why it can't be skipped |
| :--- | :--- |
| Re-stamps `date:` to today | The draft's date was set at creation and has gone stale. The date orders the timeline **and** lands in the URL. |
| Deletes the `draft: true` line | That flag is the only thing keeping the post out of the build. |
| Renames `draft_<slug>.md` → `NN_<slug>.md` | Publication order isn't knowable until you publish. |

The argument is a **filename fragment**, matched literally and case-insensitively against `draft_*.md` — not the post's title. Pass enough to be unambiguous: it publishes on exactly one match, and otherwise refuses and lists the candidates rather than guessing. It also refuses a post with no `<!-- more -->` separator, so you find that out locally instead of via a failed deploy.

A scaffolded post looks like this:

```markdown
---
date: 2026-08-23
authors: [Katy Yut]
categories:
  - Philosophy
draft: true
---

# Title of Your Article

The opening hook. Everything above the separator is the excerpt.

<!-- more -->

The rest of the article in standard plain **Markdown** syntax...
```

### The rules that will bite you

* **Every post needs a `<!-- more -->` separator.** Text above it becomes the excerpt shown on `/blog/` and on the home page, followed by a "Continue reading" link. `mkdocs.yml` sets `post_excerpt: required`, so a post without one **fails the build** — deliberately. The alternative default silently publishes the entire article into the timeline, which hides the fact that comments and the newsletter signup live only on the post page itself.
* **The date is stamped by a script, never made dynamic.** `post_url_format` is `{date}/{slug}`, so the date is part of the post's URL. A date that re-evaluated each build would change the URL on every deploy, breaking inbound links and orphaning that post's comment thread (Cusdis keys threads on `page.url`). YAML front matter is static data anyway — there is no `today()` to put there. A draft's date is a **placeholder** that `publish-post.sh` overwrites; don't bother keeping it current by hand.
* **A draft still needs a *valid* date.** `date: TBD` fails the build even with `draft: true`, because the blog plugin validates front matter *before* it checks whether a post is excluded. That's why drafts carry a real (if stale) date rather than a placeholder string.

### Other things worth knowing

* **The blank post template lives at `templates/post.md`, outside `docs/` on purpose.** Anything inside `docs/blog/posts/` is a *real post* to MkDocs — it gets a URL, appears in the timeline and the home page list, and must satisfy the excerpt rule. Keeping the template outside `docs/` means MkDocs never sees it.
* **The filename and the URL are independent.** The published slug is derived from the H1 title, not the filename — `01_how_to_open_and_invest_in_roth_ira.md` publishes as `/blog/2026/08/24/how-to-open-and-invest-in-a-roth-ira/`. Renaming a file is safe; **changing an H1 moves the URL** and orphans its comments.
* **The `NN_` prefix orders nothing that readers see.** The timeline is sorted by descending `date`; the prefix is a filesystem convenience so posts list in publication order locally. It's assigned at publish time precisely because publication order isn't knowable while drafting.
* **Put images next to the post** in `docs/blog/posts/` and reference them by bare filename (`![alt](01a.jpeg)`). Because the published URL differs from the source path, co-locating is the most reliable option.
* **New posts appear on the home page automatically** via `hooks/recent_posts.py` — no need to edit `docs/index.md`. A post with no `date` is treated as a draft and skipped.

---

## Publishing Live

Deployment is automated. Vercel watches the repository, so any change pushed to `main` triggers a cloud rebuild.

```bash
git add .
git commit -m "feat: publish a brand new essay topic"
git push origin main
```
*Changes appear live on the domain within roughly 60 seconds.*

---

## Known Quirks & Deployment Notes (Don't Forget!)

* **Vercel Build Command Configuration:** Because Vercel's global servers block standard external `pip` global execution path write permissions (following PEP 668), the `compiler command` string in `vercel.json` bypasses the system environment check using specific Python flags:
  ```json
  "buildCommand": "pip install poetry --break-system-packages && python -m poetry install --no-root && python -m poetry run mkdocs build"
  ```
* **Post Subfolder Requirements:** The timeline engine will look right past posts if they sit in the root of the blog folder. They must stay nested inside `docs/blog/posts/`.
* **Author Errors:** If a blog markdown file references an author name (e.g., `authors: [Katy Yut]`), that name must perfectly match a key definition mapping layout inside `docs/blog/.authors.yml`.
* **Anything Added After A Post Goes In `comments.html`:** Material ships `partials/comments.html` as an empty stub and includes it last in its own `content.html`, which makes it the theme's designated "end of the page content" hook. Both the Cusdis thread and the Kit newsletter form hang off it. Extend *that* file rather than copying out `content.html` — a copied theme template silently goes stale on upgrade, and `--strict` will not warn you.

---

## License

The code in this repository — the MkDocs config, the theme overrides, the
publishing scripts, the home-page hook — is [MIT licensed](LICENSE). Take it
and build your own blog; just keep the copyright notice.

That covers the code only. The writing published at
[blog.the-examined-life.com](https://blog.the-examined-life.com) is
© 2026 Katy Yut, all rights reserved, and is not in this repository. The single
post in `docs/blog/posts/` is a throwaway example and MIT like the rest.
