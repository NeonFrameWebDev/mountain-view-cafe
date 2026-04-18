# Mountain View Cafe and Bakery

Speculative website for Mountain View Cafe and Bakery, a family-owned scratch cafe in Green Valley, Arizona, baking and cooking from scratch since 2014.

Built by [NeonFrame Web Design](https://neonframewebdesign.com).

## Live

Deployed via GitHub Pages: https://neonframewebdev.github.io/mountain-view-cafe/

## Stack

Pure HTML / CSS / JS. No build step. Deploys directly to GitHub Pages.

## Local development

```bash
python3 -m http.server 8765
# visit http://localhost:8765/
```

## Tests

```bash
./tests/check.sh
```

Checks asset path integrity, internal anchors, alt text, required meta, nav consistency, image headers, CSS/JS syntax, and enforces a no-em-dashes or en-dashes rule across all source files.

## Brand system

Palette and typography pulled directly from their existing site (via the Wayback Machine snapshot of mvcafebakery.com):

- Primary: `#bdbc5f` (olive, matches their actual wall color)
- Accent: `#0a0a0a` (ink), `#FBF7EB` (warm cream)
- Display: Josefin Slab (their actual heading font)
- Body: Cantarell (their actual body font)
- Script: Caveat (our addition, used sparingly)

## Asset sources

Every image is sourced from a real, public Mountain View Cafe and Bakery property. No stock, no AI. See [IMAGE_CREDITS.md](./IMAGE_CREDITS.md) for every source URL.
