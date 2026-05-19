#!/usr/bin/env python3
"""Generate the MealMark iOS app icon assets."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
ICONSET = ROOT / "apps/ios-food-wallet/AppStore/Assets.xcassets/AppIcon.appiconset"
CONTENTS = ICONSET / "Contents.json"


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def blend(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(lerp(x, y, t) for x, y in zip(a, b))


def rgba(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return color[0], color[1], color[2], alpha


def rounded_rectangle_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def draw_soft_ellipse(
    layer: Image.Image,
    bbox: tuple[int, int, int, int],
    color: tuple[int, int, int],
    alpha: int,
    blur: int,
) -> None:
    soft = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(soft).ellipse(bbox, fill=rgba(color, alpha))
    soft = soft.filter(ImageFilter.GaussianBlur(blur))
    layer.alpha_composite(soft)


def draw_rotated_rounded_rect(
    base: Image.Image,
    center: tuple[int, int],
    size: tuple[int, int],
    radius: int,
    angle: float,
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    pad = max(size) // 2
    tile = Image.new("RGBA", (size[0] + pad * 2, size[1] + pad * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(tile)
    box = (pad, pad, pad + size[0], pad + size[1])
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)
    rotated = tile.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(rotated, (center[0] - rotated.width // 2, center[1] - rotated.height // 2))


def render_master(size: int = 1024) -> Image.Image:
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    pixels = image.load()
    top_left = (176, 250, 86)
    top_right = (74, 220, 205)
    bottom_left = (112, 88, 241)
    bottom_right = (27, 190, 142)

    for y in range(size):
        fy = y / (size - 1)
        for x in range(size):
            fx = x / (size - 1)
            top = blend(top_left, top_right, fx)
            bottom = blend(bottom_left, bottom_right, fx)
            base = blend(top, bottom, fy)
            vignette = min(1.0, math.hypot(fx - 0.5, fy - 0.52) * 1.45)
            shade = 1.0 - 0.25 * vignette
            pixels[x, y] = (round(base[0] * shade), round(base[1] * shade), round(base[2] * shade), 255)

    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw_soft_ellipse(glow, (-120, -70, int(660 * scale), int(560 * scale)), (255, 255, 160), 80, int(42 * scale))
    draw_soft_ellipse(glow, (int(500 * scale), int(470 * scale), int(1180 * scale), int(1140 * scale)), (36, 68, 255), 72, int(72 * scale))
    image.alpha_composite(glow)

    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw_soft_ellipse(
        shadow,
        (int(230 * scale), int(655 * scale), int(800 * scale), int(890 * scale)),
        (13, 35, 29),
        120,
        int(34 * scale),
    )
    image.alpha_composite(shadow)

    draw_rotated_rounded_rect(
        image,
        (int(502 * scale), int(516 * scale)),
        (int(412 * scale), int(528 * scale)),
        int(206 * scale),
        -11,
        (23, 27, 25, 255),
    )
    draw_rotated_rounded_rect(
        image,
        (int(502 * scale), int(516 * scale)),
        (int(366 * scale), int(486 * scale)),
        int(183 * scale),
        -11,
        (250, 255, 234, 255),
    )
    draw_rotated_rounded_rect(
        image,
        (int(496 * scale), int(508 * scale)),
        (int(330 * scale), int(448 * scale)),
        int(165 * scale),
        -11,
        (247, 179, 65, 255),
    )

    body_highlight = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw_soft_ellipse(
        body_highlight,
        (int(350 * scale), int(225 * scale), int(655 * scale), int(620 * scale)),
        (255, 244, 142),
        160,
        int(24 * scale),
    )
    image.alpha_composite(body_highlight)

    draw = ImageDraw.Draw(image)
    draw.line(
        [
            (int(500 * scale), int(305 * scale)),
            (int(514 * scale), int(502 * scale)),
            (int(512 * scale), int(651 * scale)),
        ],
        fill=(119, 80, 41, 255),
        width=int(18 * scale),
        joint="curve",
    )

    eye_y = int(411 * scale)
    for x in (int(430 * scale), int(579 * scale)):
        draw.ellipse(
            (x - int(37 * scale), eye_y - int(45 * scale), x + int(37 * scale), eye_y + int(45 * scale)),
            fill=(19, 24, 22, 255),
        )
        draw.ellipse(
            (x - int(13 * scale), eye_y - int(24 * scale), x + int(7 * scale), eye_y - int(4 * scale)),
            fill=(255, 255, 255, 245),
        )

    smile_points = [
        (int(430 * scale), int(568 * scale)),
        (int(478 * scale), int(612 * scale)),
        (int(566 * scale), int(526 * scale)),
    ]
    draw.line(smile_points, fill=(18, 28, 24, 255), width=int(34 * scale), joint="curve")
    draw.line(smile_points, fill=(246, 255, 232, 255), width=int(21 * scale), joint="curve")

    sparkle = Image.new("RGBA", image.size, (0, 0, 0, 0))
    sparkle_draw = ImageDraw.Draw(sparkle)
    for cx, cy, r in [
        (238, 244, 28),
        (768, 245, 22),
        (235, 786, 21),
    ]:
        cx = int(cx * scale)
        cy = int(cy * scale)
        r = int(r * scale)
        sparkle_draw.polygon(
            [(cx, cy - r), (cx + r // 3, cy - r // 3), (cx + r, cy), (cx + r // 3, cy + r // 3), (cx, cy + r), (cx - r // 3, cy + r // 3), (cx - r, cy), (cx - r // 3, cy - r // 3)],
            fill=(255, 255, 222, 220),
        )
    image.alpha_composite(sparkle)

    return image.convert("RGB")


def render_small(master: Image.Image, size: int) -> Image.Image:
    if size >= 58:
        return master.resize((size, size), Image.Resampling.LANCZOS)
    simplified = render_master(512).resize((size, size), Image.Resampling.LANCZOS)
    return simplified


def main() -> int:
    contents = json.loads(CONTENTS.read_text(encoding="utf-8"))
    master = render_master(1024)
    for image in contents["images"]:
        filename = image.get("filename")
        if not filename:
            continue
        size_pt = float(image["size"].split("x", 1)[0])
        scale = int(image["scale"].removesuffix("x"))
        pixels = round(size_pt * scale)
        output = render_small(master, pixels)
        output.save(ICONSET / filename, format="PNG", optimize=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
