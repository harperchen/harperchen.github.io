#!/usr/bin/env bash
# Assemble the full site into _site/: homepage at / and Hexo blog at /blog/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$ROOT/_site"
BLOG_SRC="$ROOT/blog-src"

rm -rf "$SITE"
mkdir -p "$SITE"

# Homepage and other static assets at site root (exclude blog source / tooling)
rsync -a \
  --exclude='.git' \
  --exclude='.github' \
  --exclude='.gitignore' \
  --exclude='blog-src' \
  --exclude='_site' \
  --exclude='scripts' \
  --exclude='node_modules' \
  --exclude='README.md' \
  "$ROOT/" "$SITE/"

# Build Hexo blog
cd "$BLOG_SRC"
if [[ ! -d node_modules ]]; then
  npm ci
fi
npx hexo clean
npx hexo generate

mkdir -p "$SITE/blog"
rsync -a "$BLOG_SRC/public/" "$SITE/blog/"

# Ensure GitHub Pages does not run Jekyll on the assembled site
touch "$SITE/.nojekyll"

echo "Built site at $SITE"
