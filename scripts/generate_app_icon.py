#!/usr/bin/env python3
"""
Nocturne App Icon Generator
Produces a 1024x1024 opaque RGB PNG at:
  SpotiStats/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png

Design: lo-fi night-city. Vertical gradient sky (indigo-purple top -> deep violet bottom),
crescent moon upper-right with soft glow, sparse faint stars, city skyline silhouette
with tiny lit windows.

Run from the repo root:
  python3 scripts/generate_app_icon.py
"""

import math
import os
import random
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "Pillow"])
    from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024

# Output path (relative to repo root, which is where we expect to be run from)
OUT_DIR = Path(__file__).parent.parent / "SpotiStats/Resources/Assets.xcassets/AppIcon.appiconset"
OUT_PATH = OUT_DIR / "Icon-1024.png"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_color(c1: tuple, c2: tuple, t: float) -> tuple:
    return tuple(int(lerp(a, b, t)) for a, b in zip(c1, c2))


def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def build_gradient(width: int, height: int, top_hex: str, bottom_hex: str) -> Image.Image:
    """Smooth vertical gradient, top -> bottom."""
    img = Image.new("RGB", (width, height))
    top = hex_to_rgb(top_hex)
    bot = hex_to_rgb(bottom_hex)
    pixels = img.load()
    for y in range(height):
        t = y / (height - 1)
        # Ease in/out with a slight curve so mid-sky is richer
        t_eased = t * t * (3 - 2 * t)  # smoothstep
        c = lerp_color(top, bot, t_eased)
        for x in range(width):
            pixels[x, y] = c
    return img


def draw_stars(draw: ImageDraw.ImageDraw, rng: random.Random, sky_bottom: int) -> None:
    """Scatter faint small dots in the upper sky."""
    n_stars = 60
    for _ in range(n_stars):
        x = rng.randint(0, SIZE - 1)
        y = rng.randint(0, int(sky_bottom * 0.72))
        radius = rng.choice([0, 0, 0, 1, 1])  # mostly 1px, some 2px
        alpha = rng.randint(100, 200)
        brightness = rng.randint(180, 255)
        color = (brightness, brightness, int(brightness * 0.9))
        if radius == 0:
            draw.point((x, y), fill=color)
        else:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def draw_moon_glow(img: Image.Image, cx: int, cy: int, r: int) -> Image.Image:
    """Add a soft diffuse glow behind the crescent."""
    glow_layer = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    # Multi-pass with increasing radius, decreasing brightness
    for factor, brightness in [(2.8, 40), (2.2, 60), (1.7, 80), (1.35, 60)]:
        gr = int(r * factor)
        gd.ellipse((cx - gr, cy - gr, cx + gr, cy + gr),
                   fill=(brightness, int(brightness * 0.8), int(brightness * 1.1)))
    glow_blurred = glow_layer.filter(ImageFilter.GaussianBlur(radius=42))
    return Image.blend(img, glow_blurred, alpha=0.55)


def draw_crescent(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int,
                  gradient_top: tuple, gradient_bot: tuple) -> None:
    """
    Draw a crescent moon:
    1. Filled light-purple/off-white circle.
    2. Overlay an offset circle in the background gradient colour to carve the crescent.
    """
    moon_color = hex_to_rgb("#E8DEFF")
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=moon_color)

    # Carve offset: shift up-left to leave a crescent on the lower-right
    offset_x = int(r * 0.38)
    offset_y = int(r * -0.10)
    # The carve colour matches the sky gradient at the moon's y position
    t = cy / (SIZE - 1)
    t_eased = t * t * (3 - 2 * t)
    carve_color = lerp_color(gradient_top, gradient_bot, t_eased)
    cr = int(r * 0.92)
    ccx = cx + offset_x
    ccy = cy + offset_y
    draw.ellipse((ccx - cr, ccy - cr, ccx + cr, ccy + cr), fill=carve_color)


def draw_skyline(draw: ImageDraw.ImageDraw, rng: random.Random,
                 ground_y: int, silhouette_color: tuple,
                 window_color: tuple) -> None:
    """
    City skyline: random-ish rectangle buildings from left to right,
    with tiny lit windows scattered on them.
    """
    # Deterministic building layout
    buildings = []
    x = -10
    while x < SIZE + 20:
        w = rng.randint(28, 90)
        h = rng.randint(60, 280)
        buildings.append((x, w, h))
        x += w + rng.randint(-6, 8)  # slight overlap / gap

    for (bx, bw, bh) in buildings:
        top_y = ground_y - bh
        draw.rectangle((bx, top_y, bx + bw, ground_y), fill=silhouette_color)

        # Occasional pointed or stepped roof detail (keep it simple)
        if rng.random() < 0.25:
            peak_x = bx + bw // 2
            draw.polygon([(bx, top_y), (peak_x, top_y - rng.randint(15, 40)),
                           (bx + bw, top_y)], fill=silhouette_color)

        # Tiny lit windows: small squares/rectangles inside the building body
        margin_x = 6
        margin_y = 10
        win_w, win_h = 4, 4
        col_step = 10
        row_step = 10
        for wy in range(top_y + margin_y, ground_y - margin_y - win_h, row_step):
            for wx in range(bx + margin_x, bx + bw - margin_x - win_w, col_step):
                if rng.random() < 0.28:
                    draw.rectangle((wx, wy, wx + win_w, wy + win_h), fill=window_color)


def generate() -> None:
    rng = random.Random(42)  # fixed seed -> deterministic output

    # Colours
    sky_top = "#3B2A7A"
    sky_bot = "#0D0620"
    silhouette_hex = "#160A2E"
    window_hex = "#A78BFA"
    gradient_top_rgb = hex_to_rgb(sky_top)
    gradient_bot_rgb = hex_to_rgb(sky_bot)
    silhouette_rgb = hex_to_rgb(silhouette_hex)
    window_rgb = hex_to_rgb(window_hex)

    # 1. Background gradient
    img = build_gradient(SIZE, SIZE, sky_top, sky_bot)

    # 2. Moon glow (blend before drawing on top)
    moon_cx, moon_cy, moon_r = 660, 310, 145
    img = draw_moon_glow(img, moon_cx, moon_cy, moon_r)

    draw = ImageDraw.Draw(img)

    # 3. Stars (behind moon)
    sky_bottom_y = int(SIZE * 0.70)
    draw_stars(draw, rng, sky_bottom_y)

    # 4. Crescent moon
    draw_crescent(draw, moon_cx, moon_cy, moon_r, gradient_top_rgb, gradient_bot_rgb)

    # 5. Skyline (bottom 30%)
    ground_y = int(SIZE * 0.98)
    sky_limit_y = int(SIZE * 0.70)
    draw_skyline(draw, rng, ground_y, silhouette_rgb, window_rgb)

    # 6. Ground fill beneath buildings (solid dark strip)
    draw.rectangle((0, ground_y, SIZE, SIZE), fill=silhouette_rgb)

    # Verify opaque RGB
    assert img.mode == "RGB", f"Expected RGB, got {img.mode}"
    assert img.size == (SIZE, SIZE), f"Expected {SIZE}x{SIZE}, got {img.size}"

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(str(OUT_PATH), "PNG")
    print(f"Saved {img.size} {img.mode} icon to: {OUT_PATH}")


if __name__ == "__main__":
    generate()
