#!/usr/bin/env python3
"""
Offline unit tests for the Session Broker (workspace-scoped provider
configuration) in nubifer-workspace.

Covers modern-cloud-auth Requirement 1, tasks 1.1-1.3:
- scoped provider dir lifecycle (create / delete / migration)
- env injection of AWS_CONFIG_FILE, AWS_SHARED_CREDENTIALS_FILE,
  CLOUDSDK_CONFIG, AZURE_CONFIG_DIR
- generated AWS config preserving credential_process wiring
- token cache cleanup on workspace delete

No network, no gpg/pass, no D-Bus: HOME is a temp dir and subprocess.run
is mocked out.
"""

import contextlib
import io
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import importlib.util
from importlib.machinery import SourceFileLoader

# nubifer-workspace has no .py extension - load it explicitly
_WS_PATH = str(Path(__file__).resolve().parent.parent / 'nubifer-workspace')
_loader = SourceFileLoader('nubifer_workspace', _WS_PATH)
_spec = importlib.util.spec_from_loader('nubifer_workspace', _loader)
nw = importlib.util.module_from_spec(_spec)
_loader.exec_module(nw)


class SessionBrokerTestCase(unittest.TestCase):
    """Base: isolated HOME, no subprocesses, no stdin."""

    def setUp(self):
        self.tmp_home = tempfile.mkdtemp(prefix='nubifer-test-home-')
        self._old_home = os.environ.get('HOME')
        os.environ['HOME'] = self.tmp_home

        # Never spawn real processes (dbus-send, systemd-run, gnome helper)
        self._subprocess_patch = mock.patch.object(
            nw.subprocess, 'run',
            return_value=mock.Mock(returncode=0, stdout='', stderr=''))
        self._subprocess_patch.start()

        self.manager = nw.WorkspaceManager()

    def tearDown(self):
        self._subprocess_patch.stop()
        if self._old_home is not None:
            os.environ['HOME'] = self._old_home
        else:
            os.environ.pop('HOME', None)
        shutil.rmtree(self.tmp_home, ignore_errors=True)

    # -- helpers ---------------------------------------------------------

    def _create_workspace(self, name='test-ws', provider='aws',
                          account_id='123456789012', region='us-east-1',
                          credential_id=None):
        with contextlib.redirect_stdout(io.StringIO()):
            workspace_id = self.manager.create_workspace(
                name=name,
                provider=provider,
                account_id=account_id,
                region=region,
                credential_id=credential_id,
                skip_confirm=True,
            )
        self.assertIsNotNone(workspace_id, "workspace creation failed")
        return workspace_id

    def _write_legacy_workspace(self, workspace_id='legacy0123456789',
                                name='legacy-ws'):
        """Simulate a pre-Session-Broker workspace: JSON only, no data dir."""
        workspace = {
            'workspace_id': workspace_id,
            'name': name,
            'provider': 'aws',
            'account_id': '999999999999',
            'account_name': 'legacy-account',
            'region': 'eu-west-1',
            'credential_id': None,
            'read_only': True,
            'created_at': '2025-11-01T00:00:00',
            'last_used': None,
            'theme': nw.PROVIDER_COLORS['aws'],
            'environment': {
                'NUBIFER_WORKSPACE_PROVIDER': 'aws',
                'NUBIFER_WORKSPACE_ACCOUNT': 'legacy-account',
                'NUBIFER_WORKSPACE_ACCOUNT_ID': '999999999999',
                'AWS_DEFAULT_REGION': 'eu-west-1',
                'AWS_REGION': 'eu-west-1',
                'AWS_ACCOUNT_ID': '999999999999',
            },
        }
        ws_file = self.manager.workspace_dir / f"{workspace_id}.json"
        with open(ws_file, 'w') as f:
            json.dump(workspace, f)
        return workspace_id

    def _env_output(self, workspace_id):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.manager.export_environment(workspace_id)
        return buf.getvalue()

    def _providers_dir(self, workspace_id):
        return (Path(self.tmp_home) / '.config' / 'nubifer' / 'workspaces'
                / workspace_id / 'providers')


class TestProviderDirLifecycle(SessionBrokerTestCase):

    def test_create_workspace_creates_scoped_provider_dirs(self):
        workspace_id = self._create_workspace()
        providers = self._providers_dir(workspace_id)

        for sub in ('aws', 'gcloud', 'azure'):
            self.assertTrue((providers / sub).is_dir(),
                            f"missing scoped dir: providers/{sub}")
        self.assertTrue((providers / 'aws' / 'sso' / 'cache').is_dir(),
                        "missing AWS SSO cache dir")
        self.assertTrue((providers / 'aws' / 'config').is_file())
        self.assertTrue((providers / 'aws' / 'credentials').is_file())

    def test_scoped_dirs_have_private_permissions(self):
        workspace_id = self._create_workspace()
        providers = self._providers_dir(workspace_id)

        self.assertEqual(os.stat(providers).st_mode & 0o777, 0o700)
        self.assertEqual(
            os.stat(providers / 'aws' / 'config').st_mode & 0o777, 0o600)
        self.assertEqual(
            os.stat(providers / 'aws' / 'credentials').st_mode & 0o777, 0o600)

    def test_generated_aws_config_preserves_credential_process(self):
        workspace_id = self._create_workspace(region='us-west-2',
                                              credential_id='prod-cred')
        config = (self._providers_dir(workspace_id) / 'aws' / 'config').read_text()

        self.assertIn('[default]', config)
        self.assertIn(
            'credential_process = '
            '/usr/local/bin/nubifer-aws-credential-helper prod-cred',
            config)
        self.assertIn('region = us-west-2', config)

    def test_generated_aws_config_defaults_credential_name(self):
        workspace_id = self._create_workspace(credential_id=None)
        config = (self._providers_dir(workspace_id) / 'aws' / 'config').read_text()
        self.assertIn(
            'credential_process = '
            '/usr/local/bin/nubifer-aws-credential-helper default',
            config)

    def test_ensure_provider_dirs_is_idempotent_and_keeps_edits(self):
        workspace_id = self._create_workspace()
        config = self._providers_dir(workspace_id) / 'aws' / 'config'
        config.write_text('# user-managed\n[default]\nregion = eu-central-1\n')

        self.manager.ensure_provider_dirs(workspace_id)

        self.assertIn('user-managed', config.read_text(),
                      "existing scoped AWS config must not be overwritten")

    def test_delete_workspace_removes_scoped_dirs_and_caches(self):
        ws_delete = self._create_workspace(name='doomed',
                                           account_id='111111111111')
        # Plant a fake cached token
        cache_file = (self._providers_dir(ws_delete) / 'aws' / 'sso'
                      / 'cache' / 'token.json')
        cache_file.write_text('{"accessToken": "fake-token"}')

        # Second workspace becomes current so the first can be deleted
        self._create_workspace(name='survivor', account_id='222222222222')

        with contextlib.redirect_stdout(io.StringIO()):
            result = self.manager.delete_workspace(ws_delete)

        self.assertTrue(result)
        self.assertFalse(cache_file.exists(), "cached token not removed")
        self.assertFalse(
            (Path(self.tmp_home) / '.config' / 'nubifer' / 'workspaces'
             / ws_delete).exists(),
            "workspace data dir not removed")

    def test_delete_refused_for_active_workspace_keeps_dirs(self):
        workspace_id = self._create_workspace()  # auto-becomes current
        with contextlib.redirect_stdout(io.StringIO()):
            result = self.manager.delete_workspace(workspace_id)

        self.assertFalse(result)
        self.assertTrue(self._providers_dir(workspace_id).is_dir(),
                        "scoped dirs must survive a refused delete")


class TestEnvInjection(SessionBrokerTestCase):

    def test_env_exports_all_four_provider_vars_with_scoped_paths(self):
        workspace_id = self._create_workspace()
        output = self._env_output(workspace_id)
        providers = self._providers_dir(workspace_id)

        expected = {
            'AWS_CONFIG_FILE': str(providers / 'aws' / 'config'),
            'AWS_SHARED_CREDENTIALS_FILE': str(providers / 'aws' / 'credentials'),
            'CLOUDSDK_CONFIG': str(providers / 'gcloud'),
            'AZURE_CONFIG_DIR': str(providers / 'azure'),
        }
        for key, value in expected.items():
            self.assertIn(f"export {key}='{value}'", output)

    def test_env_exports_workspace_id_for_credential_helper(self):
        workspace_id = self._create_workspace()
        output = self._env_output(workspace_id)
        self.assertIn(f"export NUBIFER_WORKSPACE='{workspace_id}'", output)

    def test_env_keeps_existing_static_key_exports(self):
        """Static-key flow regression: original exports must still be there."""
        workspace_id = self._create_workspace()
        output = self._env_output(workspace_id)

        self.assertIn("export AWS_DEFAULT_REGION='us-east-1'", output)
        self.assertIn("export AWS_REGION='us-east-1'", output)
        self.assertIn(f"export NUBIFER_WORKSPACE_ID='{workspace_id}'", output)
        self.assertIn("export NUBIFER_WORKSPACE_READ_ONLY='false'", output)
        self.assertIn("export PS1=", output)


class TestMigration(SessionBrokerTestCase):

    def test_env_migrates_preexisting_workspace_on_activation(self):
        workspace_id = self._write_legacy_workspace()
        self.assertFalse(self._providers_dir(workspace_id).exists())

        output = self._env_output(workspace_id)

        providers = self._providers_dir(workspace_id)
        for sub in ('aws', 'gcloud', 'azure'):
            self.assertTrue((providers / sub).is_dir(),
                            f"migration did not create providers/{sub}")
        self.assertIn(f"export CLOUDSDK_CONFIG='{providers / 'gcloud'}'", output)

    def test_migrated_aws_config_uses_workspace_region(self):
        workspace_id = self._write_legacy_workspace()
        self._env_output(workspace_id)

        config = (self._providers_dir(workspace_id) / 'aws' / 'config').read_text()
        self.assertIn('region = eu-west-1', config)
        self.assertIn('credential_process = '
                      '/usr/local/bin/nubifer-aws-credential-helper default',
                      config)

    def test_switch_migrates_preexisting_workspace(self):
        workspace_id = self._write_legacy_workspace()
        self.assertFalse(self._providers_dir(workspace_id).exists())

        with contextlib.redirect_stdout(io.StringIO()):
            result = self.manager.switch_workspace(workspace_id)

        self.assertTrue(result)
        self.assertTrue(self._providers_dir(workspace_id).is_dir())

    def test_workspace_data_dir_does_not_break_listing(self):
        workspace_id = self._create_workspace()
        workspaces = self.manager.list_workspaces()
        ids = [w['workspace_id'] for w in workspaces]
        self.assertEqual(ids, [workspace_id],
                         "data dir must not appear as a workspace")


if __name__ == '__main__':
    unittest.main()
