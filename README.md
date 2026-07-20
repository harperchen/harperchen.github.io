# harperchen.github.io

Personal homepage and blog in one repository.

| Path | Role |
|------|------|
| `/` (`index.html`, …) | Academic homepage |
| `blog-src/` | Hexo blog source (Markdown, theme, config) |
| `/blog/` (built) | Published blog |

## Local development

```bash
# Blog only (http://localhost:4000/blog/)
cd blog-src && npm ci && npx hexo server

# Full site into _site/ (homepage + /blog)
./scripts/build-site.sh
```

Requires [Node.js](https://nodejs.org/) and [Pandoc](https://pandoc.org/) (Hexo uses `hexo-renderer-pandoc`).

## Deploy

Push to `master`. GitHub Actions builds the site and publishes it.

**One-time setup:** repo **Settings → Pages → Build and deployment → Source → GitHub Actions**.

After that works, turn off Pages on the old [`harperchen/blog`](https://github.com/harperchen/blog) project site so `/blog` is served only from this repo. You can archive `BlogSource` / `blog` when ready.
