"""Resize the user-approved cropped master; no redraw or color changes.

Requires Pillow (already present on the development host). Master provenance and
hash are recorded in assets/branding/README.md. Run from repository root.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
master = Image.open(root / 'assets/branding/OpenTuner-icon-master.png').convert('RGBA')
res = root / 'android/app/src/main/res'
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    folder = res / f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    master.resize((size, size), Image.Resampling.LANCZOS).save(folder / 'ic_launcher.png')
# Android adaptive icons use a 108dp canvas: the complete approved art occupies
# its central 72dp. The tuning-fork subject stays inside the 66dp safe zone.
foreground = Image.new('RGBA', (432, 432))
art = master.resize((288, 288), Image.Resampling.LANCZOS)
foreground.alpha_composite(art, (72, 72))
folder = res / 'drawable-nodpi'
folder.mkdir(exist_ok=True)
foreground.save(folder / 'opentuner_foreground.png')
# The optional web build remains a UI preview without audio, but uses the same
# approved identity. Generated PNGs avoid a second, conflicting vector design.
for name, size in [('opentuner-icon.png', 192), ('opentuner-icon-512.png', 512), ('opentuner-favicon.png', 32)]:
    master.resize((size, size), Image.Resampling.LANCZOS).save(root / 'web' / name)
