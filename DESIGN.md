---
version: alpha
name: LibreCrawl Cloudron package
description: Original package artwork; upstream web UI is unchanged
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

## Colors and shapes

Deep navy background, mint hub and blue link strokes. White document cards use
short navy marks instead of text. The hero repeats the icon as a left-side
anchor with a connected document graph to the right. No decorative gradients,
photographs, third-party marks, screenshots or font dependencies.

## Layout and typography

`logo.png` is 256×256 and `media/hero.png` is 1188×396. Both are original
geometric raster artwork; the hero is an illustration, not a product screenshot.
The icon uses generous padding to remain legible at Cloudron launcher sizes.
No text is embedded in the assets. Documentation uses the reader's system font.

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
