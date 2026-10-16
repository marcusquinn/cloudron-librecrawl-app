---
version: alpha
name: LibreCrawl Cloudron package
description: Original package artwork and store slides; upstream web UI is unchanged
colors:
  primary: "#38d9a9"
  secondary: "#72a7ff"
  background: "#101c2c"
  surface: "#1b3049"
  on-surface: "#e8f2ff"
typography:
  body-md:
    fontFamily: system-ui
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
rounded:
  md: 8px
spacing:
  unit: 8px
---

# LibreCrawl package artwork

## Overview

Technical, quiet, high-contrast artwork showing connected web documents around
a crawler hub. The package does not re-theme or modify LibreCrawl's web UI.
Store slides pair short copy with real screenshots of that unmodified UI.

## Colors and shapes

Deep navy background, mint hub and blue link strokes. White document cards use
short navy marks instead of text. The hero repeats the icon as a left-side
anchor with a connected document graph to the right. The icon and hero use no
decorative gradients, photographs, third-party marks, screenshots or font
dependencies.

## Layout and typography

`logo.png` is 256×256 and `media/hero.png` is 1188×396. Both are original
geometric raster artwork; the hero is an illustration, not a product screenshot.
The icon uses generous padding to remain legible at Cloudron launcher sizes.
No text is embedded in the icon or hero. Documentation uses the reader's system
font.

## Store slides

`media/listing-1-audit.png` to `media/listing-5-history.png` are the first five
Cloudron `mediaLinks`, in that order, followed by the hero. Each is 2400×800: a
1200×400 layout (Cloudron's recommended 3:1) rendered at 2× for high-density
screens. The left third holds copy on the background colour: a mint uppercase
eyebrow ("LibreCrawl on Cloudron"), a short mint rule, a 35px bold headline in
on-surface and a 16.5px body line in `#a9bdd6`, all in the system UI font. The
right two thirds frame a crop of a real screenshot with a 12px top-left radius,
a `#2a4566` border and a soft shadow, bleeding off the right and bottom edges.

The screenshots show LibreCrawl commit `05a1372` on the package's disposable
test install, crawling the maintainer's public website (`www.marcusquinn.com`).
They were reviewed before use: no credentials, cookies, private hostnames or
private data are visible. Each claim in the copy was checked against the pinned
upstream source and the package defaults.

## Components, depth and responsive behavior

Flat, circular nodes with rectangular document cards and straight graph edges.
No animation or interactive components. Scale proportionally without cropping
the hub. Do not present the artwork as upstream's official logo.

## Provenance

Created for this package on 2026-10-14 by AI DevOps using an original geometric
composition rasterized with Python's standard-library PNG encoder. No upstream
or external artwork was copied and no generative-image service was used.
The repository's MIT license covers these assets. Future revisions should keep
this provenance record and dimensions; UI changes require separate upstream work.

The store slides were made on 2026-10-16 by AI DevOps. Screenshots were taken
with headless Chromium (Playwright) at 1600×1000 or 2200×1100 CSS pixels and 2×
scale, then cropped and composed in an HTML layout rendered by the same browser.
No generative-image service was used. The LibreCrawl interface shown is the
upstream project's MIT-licensed work; the composition and copy are this
package's. To refresh them after a visible upstream UI change, recapture from a
disposable install, keep this layout and order, repeat the privacy review, and
pin the new `mediaLinks` to the commit that adds the images.
