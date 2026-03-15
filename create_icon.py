#!/usr/bin/env python3
"""
AudioPilot icon generator.
Creates AppIcon.iconset + AppIcon.icns:
  Dark navy-to-indigo gradient background, white equalizer bars.
"""
import os, math, subprocess
from PIL import Image, ImageDraw, ImageFilter

def draw_icon(size: int) -> Image.Image:
    img  = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── gradient background ─────────────────────────────────────────
    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(18  + t * 45)
        g = int(18  + t * 22)
        b = int(72  + t * 110)
        draw.line([(0, y), (size - 1, y)], fill=(r, g, b, 255))

    # ── rounded-rect mask (macOS icon radius ≈ 22.4 %) ─────────────
    radius = int(size * 0.224)
    mask   = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    img.putalpha(mask)

    # ── equalizer bars ──────────────────────────────────────────────
    # 5 bars; heights create a waveform silhouette
    heights   = [0.38, 0.65, 1.00, 0.65, 0.38]
    n         = len(heights)
    bar_w     = size * 0.092
    gap       = size * 0.055
    total_w   = n * bar_w + (n - 1) * gap
    x0_start  = (size - total_w) / 2
    center_y  = size * 0.52          # slightly below center looks better
    max_h     = size * 0.54

    for i, h in enumerate(heights):
        bh  = max_h * h
        x0  = x0_start + i * (bar_w + gap)
        x1  = x0 + bar_w
        y0  = center_y - bh / 2
        y1  = center_y + bh / 2
        br  = bar_w * 0.45           # pill shape
        # soft shadow / glow via a slightly transparent layer
        draw.rounded_rectangle([x0-1, y0-1, x1+1, y1+1],
                                radius=br+1, fill=(255, 255, 255, 50))
        draw.rounded_rectangle([x0, y0, x1, y1],
                                radius=br, fill=(255, 255, 255, 235))

    # subtle inner highlight at top
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(highlight).ellipse(
        [size * 0.1, -size * 0.15, size * 0.9, size * 0.4],
        fill=(255, 255, 255, 22)
    )
    img = Image.alpha_composite(img, highlight)

    return img


def main():
    script_dir  = os.path.dirname(os.path.abspath(__file__))
    iconset_dir = os.path.join(script_dir, "AppIcon.iconset")
    icns_path   = os.path.join(script_dir, "AppIcon.icns")
    os.makedirs(iconset_dir, exist_ok=True)

    specs = {
        "icon_16x16.png":       16,
        "icon_16x16@2x.png":    32,
        "icon_32x32.png":       32,
        "icon_32x32@2x.png":    64,
        "icon_128x128.png":     128,
        "icon_128x128@2x.png":  256,
        "icon_256x256.png":     256,
        "icon_256x256@2x.png":  512,
        "icon_512x512.png":     512,
        "icon_512x512@2x.png":  1024,
    }

    for name, px in specs.items():
        icon = draw_icon(px)
        icon.save(os.path.join(iconset_dir, name), "PNG")
        print(f"  {name:30s} ({px}×{px})")

    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path],
        check=True
    )
    print(f"\n✅  AppIcon.icns created at {icns_path}")


if __name__ == "__main__":
    main()
