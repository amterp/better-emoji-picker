#!/usr/bin/env python3
"""Render the BEP app icon.

Matches the About tab's styling (SettingsView.swift:129-135): a smiling face in
SwiftUI's .yellow -> .orange gradient, running topLeading -> bottomTrailing.
Here the gradient fills a macOS-style rounded square and the face sits on top in
white, since an app icon needs a containing shape.

Everything is drawn at 4x and downsampled, because PIL's arc/ellipse rasterizer
has no antialiasing of its own.
"""

import os
from PIL import Image, ImageDraw

SS = 4                      # supersample factor
CANVAS = 1024 * SS
SQUIRCLE = 824 * SS         # macOS Big Sur+ icon grid: 824pt art in a 1024pt canvas
RADIUS = 185 * SS

# SwiftUI .yellow and .orange in sRGB.
YELLOW = (255, 204, 0)
ORANGE = (255, 149, 0)

OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "BetterEmojiPicker", "Assets.xcassets", "AppIcon.appiconset",
)

# (filename, pixel size). Several sizes serve two slots - a 32px image is both
# 16x16@2x and 32x32@1x - so they are written twice under both names.
OUTPUTS = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def diagonal_gradient(size, c0, c1):
    """Linear gradient along the topLeft -> bottomRight diagonal."""
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    for y in range(size):
        for x in range(size):
            # Projection onto the diagonal, normalised to 0..1.
            t = (x + y) / (2.0 * (size - 1))
            px[x, y] = (
                round(c0[0] + (c1[0] - c0[0]) * t),
                round(c0[1] + (c1[1] - c0[1]) * t),
                round(c0[2] + (c1[2] - c0[2]) * t),
            )
    return grad


def render():
    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    # Rounded-square mask, then paste the gradient through it.
    mask = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(CANVAS - SQUIRCLE) // 2, (CANVAS - SQUIRCLE) // 2,
         (CANVAS + SQUIRCLE) // 2, (CANVAS + SQUIRCLE) // 2],
        radius=RADIUS, fill=255,
    )
    icon.paste(diagonal_gradient(CANVAS, YELLOW, ORANGE).convert("RGBA"), (0, 0), mask)

    d = ImageDraw.Draw(icon)
    cx = cy = CANVAS // 2
    white = (255, 255, 255, 255)

    # Eyes: slightly tall ovals read better than circles at small sizes.
    eye_dx, eye_dy = 112 * SS, 86 * SS
    eye_w, eye_h = 46 * SS, 58 * SS
    for sx in (-1, 1):
        ex, ey = cx + sx * eye_dx, cy - eye_dy
        d.ellipse([ex - eye_w, ey - eye_h, ex + eye_w, ey + eye_h], fill=white)

    # Smile: an arc across the lower half, with rounded caps drawn on manually
    # since PIL's arc has flat ends.
    r = 208 * SS
    smile_y = cy + 26 * SS
    w = 52 * SS
    d.arc([cx - r, smile_y - r, cx + r, smile_y + r], start=25, end=155, fill=white, width=w)

    # PIL strokes the arc inward from the bounding box, so its centreline sits at
    # r - w/2, not r. Caps have to match or they bulge past the arc's outer edge.
    import math
    cap_r = r - w / 2
    for ang in (25, 155):
        px = cx + cap_r * math.cos(math.radians(ang))
        py = smile_y + cap_r * math.sin(math.radians(ang))
        d.ellipse([px - w / 2, py - w / 2, px + w / 2, py + w / 2], fill=white)

    return icon


def main():
    master = render()
    # Resize from the master each time rather than chaining downsamples, so no
    # size inherits another's resampling artefacts.
    for name, px in OUTPUTS:
        master.resize((px, px), Image.LANCZOS).save(os.path.join(OUT_DIR, name))
    print(f"wrote {len(OUTPUTS)} icons to {os.path.normpath(OUT_DIR)}")


if __name__ == "__main__":
    main()
