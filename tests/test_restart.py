"""Exercise setup against fake services, settings and command-line tools."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RestartTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.calls = self.base / 'calls'
        self.service = self.base / 'service'
        self.service.mkdir()
        self.venus = self.service / 'node-red-venus'
        self.venus.mkdir()
        script = (ROOT / 'setup.sh').read_text()
        script = script.replace('/usr/lib/node_modules/signalk-server', str(self.base / 'absent-signalk'))
        script = script.replace('/data/home/nodered/.node-red/settings-user.js', str(self.base / 'settings-user.js'))
        script = script.replace('/service/node-red-venus', str(self.venus))
        script = script.replace('/service/nodered', str(self.service / 'nodered'))
        (self.base / 'setup.sh').write_text(script)
        (self.base / 'boot-common.sh').write_text('register_boot_hook() { :; }\nprepare_rootfs() { :; }\n')
        commands = {
            'git': 'echo "git version 2.44.4"',
            'node': 'echo "${PATCH_RESULT:-unchanged}"',
            'svc': 'printf "%s\\n" "$*" >> "$CALLS"; exit "${SVC_RESULT:-0}"',
            'pgrep': 'exit 1',
        }
        for name, body in commands.items():
            f = self.base / name
            f.write_text('#!/bin/sh\n' + body + '\n')
            f.chmod(0o755)

    def setup_run(self, *args, **env):
        return subprocess.run(['sh', str(self.base / 'setup.sh'), *args], env=dict(os.environ, PATH=str(self.base) + ':' + os.environ['PATH'], CALLS=str(self.calls), **env), capture_output=True, text=True)

    def test_explicit_restart_repairs_unchanged_files(self):
        (self.service / 'nodered').mkdir()
        result = self.setup_run('--restart')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().strip(), '-t ' + str(self.venus))
        self.assertIn('unchanged', (self.base / 'setup.log').read_text())

    def test_unchanged_boot_does_not_restart(self):
        self.assertEqual(self.setup_run('--boot').returncode, 0)
        self.assertFalse(self.calls.exists())

    def test_changed_settings_restart_legacy_service(self):
        self.venus.rmdir()
        legacy = self.service / 'nodered'
        legacy.mkdir()
        result = self.setup_run('--boot', PATCH_RESULT='changed')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().strip(), '-t ' + str(legacy))

    def test_supervisor_failure_is_not_reported_as_success(self):
        self.assertNotEqual(self.setup_run('--restart', SVC_RESULT='1').returncode, 0)
        log = (self.base / 'setup.log').read_text()
        self.assertIn('exit code 1', log)
        self.assertNotIn('Setup complete.', log)


if __name__ == '__main__':
    unittest.main()
