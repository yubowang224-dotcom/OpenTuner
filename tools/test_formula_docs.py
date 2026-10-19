"""Check rendered formula resources, table structure and transcription boundaries."""
import math
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

import render_formulas as formulas
from test_public_export import scope

ROOT = Path(__file__).resolve().parents[1]
NS = '{http://www.w3.org/2000/svg}'


class FormulaDocumentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.items = formulas.load_catalog()['formulas']

    def test_sources_and_accessible_names(self):
        for item in self.items:
            self.assertNotRegex(item['alt'], r'\\[a-z]+|[$|]')
            self.assertTrue(item['alt'].strip())
            for reference in item['source_refs']:
                path = ROOT/reference.split(':')[0]
                self.assertTrue(path.is_file(), reference)
                if ':' in reference:
                    symbol = reference.split(':', 1)[1]
                    code = path.read_text(encoding='utf-8')
                    for token in re.findall(r'[A-Za-z_][A-Za-z_0-9]*', symbol):
                        self.assertIn(token, code, reference)
            for line in item['lines']:
                self.assertNotIn('/', line, item['id'])

    def test_svg_is_deterministic_bounded_and_self_contained(self):
        for item in self.items:
            data = (formulas.CATALOG.parent/(item['id']+'.svg')).read_bytes()
            self.assertEqual(data, formulas.render(item), item['id'])
            self.assertNotIn(b'<!DOCTYPE', data)
            root = ET.fromstring(data)
            self.assertEqual(root.find(NS+'title').text, item['alt'])
            self.assertLessEqual(float(root.attrib['viewBox'].split()[2]), 430)
            self.assertFalse(root.findall('.//'+NS+'script'))
            self.assertFalse(root.findall('.//'+NS+'foreignObject'))
            for element in root.iter():
                for key, value in element.attrib.items():
                    if key.endswith('href'):
                        self.assertTrue(value.startswith('#'))
            self.assertIn(b'fill: #ffffff', data)

    def test_feature_table_has_exactly_four_columns(self):
        text = (ROOT/'docs/feature-extraction.md').read_text(encoding='utf-8')
        rows = [line for line in text.splitlines() if line.startswith('|')]
        self.assertEqual(len(rows), 16)
        for row in rows:
            self.assertEqual(row.count('|'), 5, row)
        for number in range(1, 15):
            label = f'F{number:02}'
            self.assertIn(f'[{label}](#{label.lower()})', text)
            self.assertIn('### '+label, text)

    def test_formula_links_exist_and_no_tex_source_in_prose(self):
        used = set()
        for name in scope['public_docs']:
            if not name.endswith('.md'):
                continue
            text = (ROOT/'docs'/name).read_text(encoding='utf-8')
            self.assertNotRegex(text, r'\\(?:frac|sqrt|sum|begin|log)\b|\$\$')
            for target in re.findall(r'\]\(formulas/([a-z0-9-]+)\.svg\)', text):
                self.assertTrue((formulas.CATALOG.parent/(target+'.svg')).is_file())
                used.add(target)
        self.assertEqual(used, {item['id'] for item in self.items})

    def test_rms_floor_equivalence(self):
        for power in [0, 1e-16, 1e-12, .01, .5]:
            power_db = 10*math.log10(max(power, 1e-12))
            amplitude_db = 20*math.log10(max(math.sqrt(power), 1e-6))
            self.assertAlmostEqual(power_db, amplitude_db, places=12)
        text = (ROOT/'native/src/features.cpp').read_text(encoding='utf-8')
        self.assertIn('std::abs(pcm[i]) >= .999f', text)
        self.assertIn('x[i] = pcm[i] - f.mean', text)
        self.assertIn('10 * std::log10(std::max(energy[n]/n, 1e-12))', text)

    def test_numerical_guards_are_documented(self):
        entries = {item['id']:item for item in self.items}
        sensitivity = ''.join(entries['partial-sensitivity']['lines'])
        self.assertIn(r'\max\!\left(1,', sensitivity)
        envelope = ''.join(entries['tone-envelope']['lines'])
        self.assertIn(r'\right]', envelope)
        rank = ''.join(entries['candidate-rank']['lines'])
        self.assertIn(r'\frac{\tau}{2}', rank)
        source = (ROOT/'native/src/analyzer.cpp').read_text(encoding='utf-8')
        self.assertIn('const int minLag = 2;', source)
        self.assertIn('std::max(2, minLag)', source)


if __name__ == '__main__':
    unittest.main()
