from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.settings = self.base / 'settings-user.js'

    def patch(self, check=True):
        return subprocess.run(['node', str(ROOT / 'enable-projects.js'), str(self.settings)], check=check, capture_output=True, text=True)

    def test_preserves_javascript_and_is_idempotent(self):
        source = "// keep my comments\nmodule.exports = { callback: () => 42, matcher: /camper/i, editorTheme: { projects: { enabled: false, workflow: { mode: 'auto' } } } };\n"
        self.settings.write_text(source)
        self.settings.chmod(0o640)
        self.assertEqual(self.patch().stdout.strip(), 'changed')
        updated = self.settings.read_text()
        self.assertTrue(updated.startswith(source))
        subprocess.run(['node', '-e', "const c=require(process.argv[1]); if(c.callback()!==42 || !c.matcher.test('CAMPER') || !c.editorTheme.projects.enabled || c.editorTheme.projects.workflow.mode!=='auto') process.exit(1)", str(self.settings)], check=True)
        self.assertEqual(self.settings.stat().st_mode & 0o777, 0o640)
        backups = list(self.base.glob('*.backup-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), source)
        self.assertEqual(self.patch().stdout.strip(), 'unchanged')
        self.assertEqual(updated, self.settings.read_text())
        self.assertEqual(len(list(self.base.glob('*.backup-*'))), 1)

    def test_relative_require_and_default_workflow(self):
        (self.base / 'extra.js').write_text('module.exports = () => 7;')
        self.settings.write_text("module.exports = { callback: require('./extra') };\n")
        self.patch()
        subprocess.run(['node', '-e', "const c=require(process.argv[1]); if(c.callback()!==7 || c.editorTheme.projects.workflow.mode!=='manual') process.exit(1)", str(self.settings)], check=True)

    def test_missing_settings(self):
        self.assertEqual(self.patch().stdout.strip(), 'changed')
        self.assertEqual(self.patch().stdout.strip(), 'unchanged')

    def test_invalid_settings_untouched(self):
        for source in ['module.exports = null;', 'module.exports = { broken syntax;']:
            self.settings.write_text(source)
            self.assertNotEqual(self.patch(check=False).returncode, 0)
            self.assertEqual(self.settings.read_text(), source)
            self.assertEqual(list(self.base.glob('*.backup-*')), [])


if __name__ == '__main__':
    unittest.main()
