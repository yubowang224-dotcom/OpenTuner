"""Render editable documentation formulas to deterministic, self-contained SVG.

Uses Matplotlib mathtext; no TeX executable, browser, network or font install.
"""
import argparse
import io
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

import matplotlib
matplotlib.use('Agg')
from matplotlib import mathtext, rc_context
from matplotlib.figure import Figure
from matplotlib.font_manager import FontProperties

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'docs/formulas/source.json'
SETTINGS = {
    'text.usetex': False, 'mathtext.fontset': 'stix', 'font.family': 'STIXGeneral',
    'svg.fonttype': 'path', 'svg.hashsalt': 'OpenTuner-document-formulas-v1',
}
METADATA = {'Date': None, 'Creator': 'OpenTuner formula renderer'}
NS = 'http://www.w3.org/2000/svg'


def load_catalog():
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    ids = [item['id'] for item in catalog['formulas']]
    assert len(ids) == len(set(ids))
    assert all(re.fullmatch('[a-z][a-z0-9-]+', name) for name in ids)
    return catalog


def render(item):
    with rc_context(SETTINGS):
        font = FontProperties(size=17)
        parser = mathtext.MathTextParser('path')
        sizes = [parser.parse('$' + line + '$', dpi=72, prop=font) for line in item['lines']]
        padding, gap = 12, 10
        width = max(size.width for size in sizes) + 2 * padding
        height = sum(size.height for size in sizes) + (len(sizes)-1)*gap + 2*padding
        assert width <= 430, f'Split long formula into shorter lines: {item["id"]}'
        figure = Figure(figsize=(width/72, height/72), dpi=144,
                        facecolor='white', edgecolor='#CBD5DF', linewidth=.5)
        top = height-padding
        for line, size in zip(item['lines'], sizes):
            baseline = top-(size.height-size.depth)
            figure.text(padding/width, baseline/height, '$'+line+'$',
                        fontproperties=font, color='#172A3A',
                        horizontalalignment='left', verticalalignment='baseline')
            top -= size.height+gap
        data = io.BytesIO()
        figure.savefig(data, format='svg', metadata=METADATA,
                       facecolor='white', edgecolor='#CBD5DF')
        svg = data.getvalue().decode('utf-8')
        svg = re.sub(r'<!DOCTYPE[^>]*>\s*', '', svg, flags=re.S)
        # Matplotlib paths retain no external font dependencies.
        opening = re.search(r'<svg\b[^>]*>', svg)
        assert opening
        title = item['alt'].replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        replacement = opening[0][:-1] + ' role="img" aria-labelledby="formula-title">'
        replacement += '<title id="formula-title">' + title + '</title>'
        svg = svg[:opening.start()] + replacement + svg[opening.end():]
        root = ET.fromstring(svg)
        assert root.find('{'+NS+'}title') is not None
        assert not root.findall('.//{'+NS+'}script')
        for element in root.iter():
            for key, value in element.attrib.items():
                if key.endswith('href'):
                    assert value.startswith('#'), 'External resource in formula SVG'
        return svg.encode('utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=CATALOG.parent)
    parser.add_argument('--preview', type=Path)
    args = parser.parse_args()
    catalog = load_catalog()
    args.output.mkdir(parents=True, exist_ok=True)
    for item in catalog['formulas']:
        data = render(item)
        destination = args.output / (item['id']+'.svg')
        if args.check:
            assert destination.read_bytes() == data, f'Stale formula: {destination.name}'
        else:
            destination.write_bytes(data)
    if args.preview:
        # Diagnostic raster from the same editable source, not a phone screenshot.
        selected = catalog['formulas'][:6]
        with rc_context(SETTINGS):
            font = FontProperties(size=17)
            parser = mathtext.MathTextParser('path')
            groups = [[parser.parse('$'+line+'$', dpi=72, prop=font)
                       for line in item['lines']] for item in selected]
            height = 24 + sum(32 + sum(s.height+10 for s in sizes) for sizes in groups)
            width = max(s.width for sizes in groups for s in sizes)+32
            figure = Figure(figsize=(width/72, height/72), dpi=144, facecolor='white')
            top = height-16
            for item, sizes in zip(selected, groups):
                figure.text(16/width, top/height, item['id'], fontsize=10, color='#587080')
                top -= 16
                for line, size in zip(item['lines'], sizes):
                    baseline = top-(size.height-size.depth)
                    figure.text(16/width, baseline/height, '$'+line+'$',
                                fontproperties=font, color='#172A3A')
                    top -= size.height+10
                top -= 16
            args.preview.parent.mkdir(parents=True, exist_ok=True)
            figure.savefig(args.preview, facecolor='white', metadata={'Software': 'OpenTuner'})
    print(json.dumps({'formulas':len(catalog['formulas']), 'checked':args.check,
                      'renderer':'Matplotlib mathtext', 'external_tex':False}))


if __name__ == '__main__':
    main()
