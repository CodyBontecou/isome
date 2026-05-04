#!/usr/bin/env python3
"""
iso.me App Store Screenshot Composer — white bg / black text variant.

Ported from ~/.claude-personal/skills/aso-appstore-screenshots/compose.py
with text fill flipped to black, default background to white, and optional
per-locale font + RTL handling preserved.

Output: pixel-perfect 1290x2796 PNG matching the shipped v1.0 style.
"""

import argparse
import os
import sys
from PIL import Image, ImageDraw, ImageFont

CANVAS_W = 1290
CANVAS_H = 2796

DEVICE_W = 1030
BEZEL = 15
SCREEN_W = DEVICE_W - 2 * BEZEL
SCREEN_CORNER_R = 62

DEVICE_Y = 720

VERB_SIZE_MAX = 256
VERB_SIZE_MIN = 150
DESC_SIZE = 124
VERB_DESC_GAP = 20
DESC_LINE_GAP = 24
MAX_TEXT_W = int(CANVAS_W * 0.92)
MAX_VERB_W = int(CANVAS_W * 0.92)

DEFAULT_FONT = "/Library/Fonts/SF-Pro-Display-Black.otf"
FRAME_PATH_DEFAULT = os.path.expanduser(
    "~/.claude-personal/skills/aso-appstore-screenshots/assets/device_frame.png"
)

FONT_OVERRIDES = {
    "ja": "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc",
    "zh-Hans": "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc",
    "hi": "/System/Library/Fonts/Kohinoor.ttc",
    "bn": "/System/Library/Fonts/KohinoorBangla.ttc",
    "ar": "/System/Library/Fonts/SFArabic.ttf",
}

FONT_TTC_INDEX = {
    "ja": 0,
    "zh-Hans": 2,
    "hi": 3,
    "bn": 3,
}


def shape_arabic(text):
    import arabic_reshaper
    from bidi.algorithm import get_display

    reshaped = arabic_reshaper.reshape(text)
    return get_display(reshaped)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def load_font(font_path, size, ttc_index=0, variation=None):
    try:
        font = ImageFont.truetype(font_path, size, index=ttc_index)
    except (TypeError, OSError):
        font = ImageFont.truetype(font_path, size)
    if variation:
        try:
            font.set_variation_by_name(variation)
        except (OSError, ValueError):
            pass
    return font


def word_wrap(draw, text, font, max_w):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        test = f"{cur} {w}".strip()
        if draw.textlength(test, font=font) <= max_w:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def fit_font(text, max_w, size_max, size_min, font_path, ttc_index=0, variation=None):
    dummy = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    for size in range(size_max, size_min - 1, -4):
        font = load_font(font_path, size, ttc_index, variation)
        bbox = dummy.textbbox((0, 0), text, font=font)
        if (bbox[2] - bbox[0]) <= max_w:
            return font
    return load_font(font_path, size_min, ttc_index, variation)


def draw_centered(draw, y, text, font, fill, max_w=None):
    lines = word_wrap(draw, text, font, max_w) if max_w else [text]
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        h = bbox[3] - bbox[1]
        draw.text(
            (CANVAS_W // 2, y - bbox[1]),
            line,
            fill=fill,
            font=font,
            anchor="mt",
        )
        y += h + DESC_LINE_GAP
    return y


def compose(
    verb,
    desc,
    screenshot_path,
    output_path,
    bg_hex="#FFFFFF",
    text_hex="#000000",
    font_path=DEFAULT_FONT,
    ttc_index=0,
    frame_path=FRAME_PATH_DEFAULT,
    locale=None,
    variation=None,
):
    bg = hex_to_rgb(bg_hex)
    text_color = hex_to_rgb(text_hex)

    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (*bg, 255))
    draw = ImageDraw.Draw(canvas)

    is_arabic = locale == "ar"
    is_cjk_or_indic = locale in {"ja", "zh-Hans", "hi", "bn"}
    # CJK + Indic scripts don't use uppercase; Arabic also has no case.
    def cased(t):
        return t if (is_arabic or is_cjk_or_indic) else t.upper()

    verb_text = shape_arabic(cased(verb)) if is_arabic else cased(verb)
    desc_text = shape_arabic(cased(desc)) if is_arabic else cased(desc)

    verb_font = fit_font(
        verb_text, MAX_VERB_W, VERB_SIZE_MAX, VERB_SIZE_MIN, font_path, ttc_index, variation
    )
    desc_font = load_font(font_path, DESC_SIZE, ttc_index, variation)

    y = 200
    y = draw_centered(draw, y, verb_text, verb_font, text_color)
    y += VERB_DESC_GAP
    draw_centered(draw, y, desc_text, desc_font, text_color, max_w=MAX_TEXT_W)

    device_x = (CANVAS_W - DEVICE_W) // 2
    device_y = DEVICE_Y
    screen_x = device_x + BEZEL
    screen_y = device_y + BEZEL

    shot = Image.open(screenshot_path).convert("RGBA")
    scale = SCREEN_W / shot.width
    sc_w = SCREEN_W
    sc_h = int(shot.height * scale)
    shot = shot.resize((sc_w, sc_h), Image.LANCZOS)

    screen_h = CANVAS_H - screen_y + 500

    scr_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(scr_mask).rounded_rectangle(
        [screen_x, screen_y, screen_x + SCREEN_W, screen_y + screen_h],
        radius=SCREEN_CORNER_R,
        fill=255,
    )

    scr_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(scr_layer).rounded_rectangle(
        [screen_x, screen_y, screen_x + SCREEN_W, screen_y + screen_h],
        radius=SCREEN_CORNER_R,
        fill=(0, 0, 0, 255),
    )
    scr_layer.paste(shot, (screen_x, screen_y))
    scr_layer.putalpha(scr_mask)

    canvas = Image.alpha_composite(canvas, scr_layer)

    frame_template = Image.open(frame_path).convert("RGBA")
    frame_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    frame_layer.paste(frame_template, (device_x, device_y))
    canvas = Image.alpha_composite(canvas, frame_layer)

    canvas.convert("RGB").save(output_path, "PNG")
    print(f"wrote {output_path} ({CANVAS_W}x{CANVAS_H})", file=sys.stderr)


def main():
    p = argparse.ArgumentParser(description="iso.me App Store screenshot composer")
    p.add_argument("--verb", required=True)
    p.add_argument("--desc", required=True)
    p.add_argument("--screenshot", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--bg", default="#FFFFFF")
    p.add_argument("--text", default="#000000")
    p.add_argument("--locale")
    p.add_argument("--font")
    p.add_argument("--ttc-index", type=int, default=0)
    p.add_argument("--variation")
    p.add_argument("--frame", default=FRAME_PATH_DEFAULT)
    args = p.parse_args()

    font_path = args.font or FONT_OVERRIDES.get(args.locale, DEFAULT_FONT)
    ttc_index = args.ttc_index or FONT_TTC_INDEX.get(args.locale, 0)
    variation = args.variation or ("Black" if args.locale == "ar" else None)

    compose(
        args.verb,
        args.desc,
        args.screenshot,
        args.output,
        bg_hex=args.bg,
        text_hex=args.text,
        font_path=font_path,
        ttc_index=ttc_index,
        frame_path=args.frame,
        locale=args.locale,
        variation=variation,
    )


if __name__ == "__main__":
    main()
