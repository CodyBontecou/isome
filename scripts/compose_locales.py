#!/usr/bin/env python3
"""
Drive compose_white.py over 9 non-English locales × 4 screenshots.

Uses the English raw captures in design/screenshots/v1.0/raw/iphone/ for the
device UI and overlays localized marketing headlines on top. Outputs go to
design/screenshots/v1.0/appstore/iphone-67/{locale}/, both PNG and JPG with
an sRGB color profile embedded via macOS sips.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))

RAW_DIR = os.path.join(REPO, "design/screenshots/v1.0/raw/iphone")
OUT_ROOT = os.path.join(REPO, "design/screenshots/v1.0/appstore/iphone-67")
COMPOSE = os.path.join(HERE, "compose_white.py")

SLOTS = [
    ("01-keep-on-device", "01-settings.png"),
    ("02-capture-visits", "02-map.png"),
    ("03-record-routes", "03-map-routes.png"),
    ("04-export-history", "04-export.png"),
]

# Each locale maps to a list of (verb, desc) tuples, one per slot.
LOCALES = {
    "es": [
        ("Todo en", "tu dispositivo"),
        ("Captura", "cada lugar visitado"),
        ("Registra", "tus rutas exactas"),
        ("Exporta", "todo tu historial"),
    ],
    "fr": [
        ("100%", "sur votre appareil"),
        ("Capturez", "chaque lieu visité"),
        ("Enregistrez", "vos trajets exacts"),
        ("Exportez", "votre historique complet"),
    ],
    "pt-BR": [
        ("Tudo no", "seu dispositivo"),
        ("Capture", "cada lugar visitado"),
        ("Registre", "suas rotas exatas"),
        ("Exporte", "todo seu histórico"),
    ],
    "ru": [
        ("Только", "на устройстве"),
        ("Фиксируйте", "каждое место"),
        ("Записывайте", "точные маршруты"),
        ("Экспорт", "всей истории"),
    ],
    "ja": [
        ("端末内で完結", "100%プライベート"),
        ("訪れた場所", "すべて自動記録"),
        ("正確なルート", "完全に記録"),
        ("全履歴を", "書き出せる"),
    ],
    "zh-Hans": [
        ("完全本地", "数据保存在设备上"),
        ("自动记录", "每一个到访地点"),
        ("精准路线", "完整轨迹记录"),
        ("导出历史", "完整数据导出"),
    ],
    "ar": [
        ("على جهازك فقط", "خصوصية كاملة"),
        ("سجّل كل مكان", "تزوره تلقائياً"),
        ("سجّل مساراتك", "بدقة تامة"),
        ("صدّر سجلك", "الكامل"),
    ],
    "hi": [
        ("सब कुछ", "आपके डिवाइस पर"),
        ("हर जगह", "स्वचालित रूप से दर्ज"),
        ("सटीक मार्ग", "रिकॉर्ड करें"),
        ("पूरा इतिहास", "एक्सपोर्ट करें"),
    ],
    "bn": [
        ("সবকিছু", "আপনার ডিভাইসে"),
        ("প্রতিটি স্থান", "স্বয়ংক্রিয় রেকর্ড"),
        ("নিখুঁত রুট", "রেকর্ড করুন"),
        ("সম্পূর্ণ ইতিহাস", "এক্সপোর্ট করুন"),
    ],
}

SRGB_PROFILE = "/System/Library/ColorSync/Profiles/sRGB Profile.icc"


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout + result.stderr)
        raise SystemExit(result.returncode)
    return result


def main():
    for locale, copy in LOCALES.items():
        out_dir = os.path.join(OUT_ROOT, locale)
        os.makedirs(out_dir, exist_ok=True)

        for (slot_name, source_png), (verb, desc) in zip(SLOTS, copy):
            screenshot = os.path.join(RAW_DIR, source_png)
            png_out = os.path.join(out_dir, f"{slot_name}.png")
            jpg_out = os.path.join(out_dir, f"{slot_name}.jpg")

            print(f"[{locale}] {slot_name} — {verb} / {desc}", flush=True)

            run([
                "python3", COMPOSE,
                "--verb", verb,
                "--desc", desc,
                "--screenshot", screenshot,
                "--output", png_out,
                "--locale", locale,
            ])

            # Embed sRGB + convert to JPG for App Store Connect.
            run([
                "sips", "-s", "format", "jpeg",
                "-s", "formatOptions", "95",
                "-m", SRGB_PROFILE,
                png_out, "--out", jpg_out,
            ])
            # Also embed sRGB back into the PNG (keeps local previews aligned).
            run([
                "sips", "-m", SRGB_PROFILE,
                png_out, "--out", png_out,
            ])


if __name__ == "__main__":
    main()
