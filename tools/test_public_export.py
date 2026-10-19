"""Standard-library tests for source-distribution selection and result projection."""
import ast
import csv
import io
import json
from pathlib import Path
import re
import unittest


source = Path(__file__).with_name('export_public_source.py').read_text(encoding='utf-8')
tree = ast.parse(source)
names = {'public_docs', 'public_evidence', 'public_screenshots'}
nodes = [
    node for node in tree.body
    if isinstance(node, ast.FunctionDef) and node.name in {'public_file', 'public_document', 'check_public_document'}
    or isinstance(node, ast.Assign) and any(
        isinstance(target, ast.Name) and target.id in names for target in node.targets
    )
]
scope = {'csv': csv, 'io': io, 'json': json, 're': re}
exec(compile(ast.Module(body=nodes, type_ignores=[]), source, 'exec'), scope)
select = scope['public_file']
project = scope['public_document']


class PublicExportTests(unittest.TestCase):
    def test_complete_source_and_selected_documents(self):
        for name in ['native/src/analyzer.cpp', 'lib/app.dart', 'test/app_test.dart',
                     'tools/build-release.ps1', 'docs/evidence/m3-results.json']:
            self.assertTrue(select(name))
        for name in ['AGENTS.md', 'docs/stage-2-report.md']:
            self.assertFalse(select(name))

    def test_environment_and_process_files_are_excluded(self):
        for name in ['cpu.json', 'environment.json', 'profile.json',
                     'regression-process.json', 'manifest.json']:
            self.assertFalse(select('docs/evaluation-stage25/' + name))

    def test_nested_telemetry_removed_without_changing_accuracy(self):
        value = {'conditions': 2, 'ready': 1, 'first_cents_p95': .25,
                 'host_resource': {'cpu': 'example', 'process_cpu_seconds': 3},
                 'curves': {'guide': {'objective': 4, 'host_p95_solve_us': 8},
                            'runtime': 'example'}}
        original = json.dumps(value).encode()
        result = json.loads(project('docs/evidence/m3-results.json', original))
        self.assertEqual(result, {'conditions': 2, 'ready': 1, 'first_cents_p95': .25,
                                  'curves': {'guide': {'objective': 4}}})
        self.assertEqual(json.loads(original), value)

    def test_csv_preserves_every_acoustic_row(self):
        data = b'case,valid_frames,p95_abs_cents,first_ms,p95_compute_ms\nx,0,,80,3\ny,4,.25,100,5\n'
        output = project('docs/evaluation-stage25/summary.csv', data)
        self.assertEqual(output, b'case,valid_frames,p95_abs_cents,first_ms\nx,0,,80\ny,4,.25,100\n')
        self.assertEqual(project('docs/evidence/wave-trigger10ms.csv', data), output)

    def test_implementation_bytes_are_never_projected(self):
        data = b'// computation and platform diagnostics belong to source\n'
        self.assertEqual(project('native/tests/evaluation.cpp', data), data)
        self.assertEqual(project('tools/report_piano_m3.py', data), data)

    def test_baseline_table_keeps_acoustic_columns(self):
        data = ('| 组 | 有效 | 误差 | 单帧P95(ms) |\n|---|---|---|---|\n'
                '| sine | 4/4 | .1 | 3 |\n\n## 环境与边界\nexample\n'
                'CSV SHA-256：\nabc\n').encode()
        result = project('docs/stage-2-dsp-results.md', data).decode()
        self.assertIn('| sine | 4/4 | .1 |', result)
        self.assertNotIn('单帧P95', result)
        self.assertNotIn('example', result)
        self.assertIn('abc', result)
        self.assertEqual(project('docs/stage-2-dsp-results.md', result.encode()), result.encode())

    def test_public_projection_is_idempotent(self):
        data = b'case,p95_abs_cents,p95_compute_ms\nx,.25,3\n'
        once = project('docs/evaluation-stage25/summary.csv', data)
        self.assertEqual(project('docs/evaluation-stage25/summary.csv', once), once)
        data = json.dumps({'ready': 1, 'host_resource': {'cpu': 'example'}}).encode()
        once = project('docs/evidence/m3-results.json', data)
        self.assertEqual(project('docs/evidence/m3-results.json', once), once)

    def test_telemetry_guard_rejects_unprojected_fields(self):
        check = scope['check_public_document']
        with self.assertRaises(AssertionError):
            check('docs/example.json', b'{"process_cpu_seconds": 2}')
        with self.assertRaises(AssertionError):
            check('docs/example.csv', b'case,p95_compute_ms\nx,3\n')
        check('docs/example.json', b'{"ready": 2, "p95_cents": 0.1}')


if __name__ == '__main__':
    unittest.main()
