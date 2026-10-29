"""Rasterises the Icon A · Rewind artboard into Android launcher assets.

The art is the SVG from the design reference, rendered by Chrome so the arc
caps, arrow join and 5.5-unit centre dot match the mockup exactly.
"""

import os
import subprocess
import sys
import tempfile

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

DARK = "#0E0E0D"
ORANGE = "#FF6B3D"
CREAM = "#F3EFE6"
LIME = "#B7F34D"

ART = f"""
  <path d="M50 24 A26 26 0 1 0 76 50" stroke="{ORANGE}" stroke-width="9"
        stroke-linecap="round" fill="none"/>
  <polygon points="76,35 88,52 64,52" fill="{ORANGE}" stroke="{ORANGE}"
           stroke-width="3" stroke-linejoin="round"/>
  <path d="M50 50 V34" stroke="{CREAM}" stroke-width="5" stroke-linecap="round"/>
  <circle cx="50" cy="50" r="5.5" fill="{LIME}"/>
"""


def svg(size, *, tile_radius=None, circle=False, art_scale=1.0):
    """size = pixel size. tile_radius/circle add the dark launcher tile."""
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" '
             f'height="{size}" viewBox="0 0 100 100">']
    if tile_radius is not None:
        parts.append(f'<rect width="100" height="100" rx="{tile_radius}" fill="{DARK}"/>')
    if circle:
        parts.append('<clipPath id="c"><circle cx="50" cy="50" r="50"/></clipPath>')
        parts.append(f'<rect width="100" height="100" fill="{DARK}" clip-path="url(#c)"/>')
        parts.append('<g clip-path="url(#c)">')
    if art_scale != 1.0:
        offset = (100 - 100 * art_scale) / 2
        parts.append(f'<g transform="translate({offset},{offset}) scale({art_scale})">')
    parts.append(ART)
    if art_scale != 1.0:
        parts.append("</g>")
    if circle:
        parts.append("</g>")
    parts.append("</svg>")
    return "".join(parts)


def render(size, markup, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    html = (f'<!doctype html><html><head><style>'
            f'html,body{{margin:0;padding:0;background:transparent;overflow:hidden}}'
            f'svg{{display:block}}</style></head><body>{markup}</body></html>')
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, "icon.html")
        with open(page, "w", encoding="utf-8") as fh:
            fh.write(html)
        cmd = [
            CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
            "--force-device-scale-factor=1", f"--window-size={size},{size}",
            f"--screenshot={out_path}",
        ]
        # Keeps the rounded tile's corners transparent instead of white.
        cmd.append("--default-background-color=00000000")
        cmd.append("file:///" + page.replace("\\", "/"))
        subprocess.run(cmd, check=True, capture_output=True)
    print(f"  {os.path.relpath(out_path, ROOT)}  {size}px")


DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}

# Launcher tile: 48dp, radius 22.37% (from the artboard's own formula).
for density, scale in DENSITIES.items():
    px = round(48 * scale)
    radius = round(100 * 0.2237, 2)
    render(px, svg(px, tile_radius=radius), os.path.join(RES, f"mipmap-{density}", "ic_launcher.png"))
    render(px, svg(px, circle=True), os.path.join(RES, f"mipmap-{density}", "ic_launcher_round.png"))

# Adaptive foreground: 108dp canvas, art inside the 72dp safe zone.
for density, scale in DENSITIES.items():
    px = round(108 * scale)
    render(px, svg(px, art_scale=0.62),
           os.path.join(RES, f"mipmap-{density}", "ic_launcher_foreground.png"))

# Launch splash mark: 96dp, transparent, no tile (the window behind is dark).
for density, scale in DENSITIES.items():
    px = round(96 * scale)
    render(px, svg(px), os.path.join(RES, f"mipmap-{density}", "launch_mark.png"))

# Play Store listing icon.
render(512, svg(512, tile_radius=round(100 * 0.2237, 2)),
       os.path.join(ROOT, "design", "icon", "play-store-512.png"))
