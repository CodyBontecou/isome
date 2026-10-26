#!/usr/bin/env python3
"""Render release-gated articles outside the public deployment directory."""
import argparse
from pathlib import Path
from build_seo_pages import DRAFTS, render

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=Path('/tmp/isome-seo-drafts'))
args = parser.parse_args()
public = Path(__file__).resolve().parents[1] / 'public'
if args.output.resolve().is_relative_to(public.resolve()):
    parser.error('Draft previews must stay outside public/.')
args.output.mkdir(parents=True, exist_ok=True)
for page in DRAFTS:
    output = args.output / (page['path'].strip('/').replace('/', '-') + '.html')
    output.write_text(render(page))
    print(output)
