---
date: 2026-01-01
authors: [Katy Yut]
categories:
  - Example
---

# An Example Post

This post exists so the blog timeline, the home-page list, the Cusdis thread and
the newsletter form all have something to render in a fresh clone. The real
writing is at [blog.the-examined-life.com](https://blog.the-examined-life.com).

Everything above the separator below is the **excerpt** — it is what appears on
`/blog/` and on the home page, followed by a "Continue reading" link.

<!-- more -->

Everything below the separator appears only on the post's own page. That split
is why the separator is mandatory: `mkdocs.yml` sets `post_excerpt: required`,
so a post without one fails the build rather than silently dumping its full text
into the timeline.

A few things this file demonstrates:

- `date:` orders the timeline **and** lands in the URL, because
  `post_url_format` is `{date}/{slug}`.
- `authors:` must match a key in `docs/blog/.authors.yml` exactly.
- The URL slug comes from the H1, not the filename — this file publishes as
  `/blog/2026/01/01/an-example-post/`.
- The `NN_` filename prefix is a local convenience recording publication order.
  Readers never see it.

See the README for the full writing workflow.
