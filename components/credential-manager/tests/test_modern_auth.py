#!/usr/bin/env python3
"""
Offline unit tests for guided SSO login and session visibility in
nubifer-creds (modern-cloud-auth Requirements 2, 3, 4.1, 5.1).

Covers:
- provider login dispatch (aws sso login / az login / gcloud auth login)
  executed with the workspace-scoped provider environment
- non-secret SSO configuration storage in the workspace config
- session metadata capture (identity, expiry) and audit entries
- role-binding driven config generation (via the Session Broker)
- precedence ordering in the generated AWS config (SSO > static)
- status table rendering for sso / static / none modes

No network, no real gpg/pass/provider CLIs: HOME is a temp dir and
subprocess.run is mocked out.
"""

import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

import importlib.util
from importlib.machinery import SourceFileLoader

# nubifer-creds has no .py extension - load it explicitly
_NC_PATH = str(Path(__file__).resolve().parent.parent / 'nubifer-creds')
_loader = SourceFileLoader('nubifer_creds', _NC_PATH)
_spec = importlib.util.spec_from_loader('nubifer_creds', _loader)
nc = importlib.util.module_from_spec(_spec)
_loader.exec_module(nc)

WS_ID = 'cred0123456789ab'


class ModernAuthTestCase(unittest.TestCase):
    """Base: isolated HOME, recorded (fake) subprocess calls."""

    def setUp(self):
        self.tmp_home = tempfile.mkdtemp(prefix='nubifer-test-home-')
        self._old_home = os.environ.get('HOME')
        os.environ['HOME'] = self.tmp_home
        os.environ.pop('NUBIFER_WORKSPACE_ID', None)
        os.environ.pop('PASSWORD_STORE_DIR', None)

        self.workspace_dir = (Path(self.tmp_home) / '.config' / 'nubifer'
                              / 'workspaces')
        self.audit_log = (Path(self.tmp_home) / '.config' / 'nubifer'
                          / 'audit.log')

        self.calls = []
        self.fail_commands = set()  # e.g. {'aws sso login'}

        def fake_run(cmd, **kwargs):
            cmd = [str(c) for c in cmd]
            self.calls.append((cmd, kwargs))
            joined = ' '.join(cmd[:3])
            rc = 1 if any(joined.startswith(f) for f in self.fail_commands) else 0
            return mock.Mock(returncode=rc,
                             stdout=self._stdout_for(cmd), stderr='')

        self._subprocess_patch = mock.patch.object(
            nc.subprocess, 'run', side_effect=fake_run)
        self._subprocess_patch.start()

    def tearDown(self):
        self._subprocess_patch.stop()
        if self._old_home is not None:
            os.environ['HOME'] = self._old_home
        else:
            os.environ.pop('HOME', None)
        shutil.rmtree(self.tmp_home, ignore_errors=True)

    @staticmethod
    def _stdout_for(cmd):
        joined = ' '.join(cmd[:4])
        if joined.startswith('aws sts get-caller-identity'):
            return json.dumps(
                {'Arn': 'arn:aws:sts::123456789012:assumed-role/Dev/user'})
        if joined.startswith('az account show'):
            return json.dumps({'user': {'name': 'user@example.com'}})
        if joined.startswith('gcloud config get-value'):
            return 'user@example.com\n'
        return ''

    # -- helpers ---------------------------------------------------------

    def _write_workspace(self, workspace_id=WS_ID, provider='aws',
                         account_id='123456789012', region='us-east-1',
                         **extra):
        workspace = {
            'workspace_id': workspace_id,
            'name': 'test-ws',
            'provider': provider,
            'account_id': account_id,
            'account_name': 'test-account',
            'region': region,
            'credential_id': None,
            'read_only': True,
            'created_at': '2026-07-01T00:00:00',
            'last_used': None,
            'environment': {},
        }
        workspace.update(extra)
        self.workspace_dir.mkdir(parents=True, exist_ok=True)
        with open(self.workspace_dir / f"{workspace_id}.json", 'w') as f:
            json.dump(workspace, f)
        return workspace_id

    def _read_workspace(self, workspace_id=WS_ID):
        with open(self.workspace_dir / f"{workspace_id}.json") as f:
            return json.load(f)

    def _session_manager(self, workspace_id=WS_ID):
        return nc.SessionManager(workspace_id=workspace_id)

    def _providers_dir(self, workspace_id=WS_ID):
        return self.workspace_dir / workspace_id / 'providers'

    def _plant_static_creds(self, provider='aws', profile='default',
                            workspace_id=WS_ID):
        cred_dir = (Path(self.tmp_home) / '.password-store' / 'nubifer'
                    / workspace_id / 'cloud' / provider / profile)
        cred_dir.mkdir(parents=True, exist_ok=True)
        (cred_dir / 'access-key-id.gpg').write_bytes(b'gpg-blob')

    def _find_call(self, *prefix):
        prefix = list(prefix)
        for cmd, kwargs in self.calls:
            if cmd[:len(prefix)] == prefix:
                return cmd, kwargs
        return None, None

    def _status_json(self, workspace_id=WS_ID):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self._session_manager(workspace_id).status(json_output=True)
        return json.loads(buf.getvalue())

    def _audit_lines(self, needle):
        if not self.audit_log.exists():
            return []
        return [line for line in self.audit_log.read_text().splitlines()
                if needle in line]


SSO_AWS = {'aws': {'sso_start_url': 'https://acme.awsapps.com/start',
                   'sso_region': 'us-east-1',
                   'sso_account_id': '123456789012',
                   'sso_role_name': 'DevAccess'}}


class TestProviderDispatch(ModernAuthTestCase):

    def test_aws_login_runs_sso_login_in_workspace_scope(self):
        self._write_workspace(sso=SSO_AWS)
        with contextlib.redirect_stdout(io.StringIO()):
            ok = self._session_manager().login('aws')

        self.assertTrue(ok)
        cmd, kwargs = self._find_call('aws', 'sso', 'login')
        self.assertIsNotNone(cmd, "aws sso login not invoked")
        self.assertEqual(cmd, ['aws', 'sso', 'login',
                               '--sso-session', 'nubifer'])
        env = kwargs['env']
        providers = str(self._providers_dir())
        self.assertEqual(env['AWS_CONFIG_FILE'],
                         str(self._providers_dir() / 'aws' / 'config'))
        self.assertTrue(env['AWS_SHARED_CREDENTIALS_FILE'].startswith(providers))
        self.assertEqual(env['NUBIFER_WORKSPACE'], WS_ID)

    def test_aws_login_without_sso_config_hints_setup(self):
        self._write_workspace()  # no SSO configuration stored
        stderr = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(stderr):
            ok = self._session_manager().login('aws')

        self.assertFalse(ok)
        self.assertIsNone(self._find_call('aws', 'sso', 'login')[0])
        self.assertIn('login setup -t aws', stderr.getvalue())
        self.assertTrue(self._audit_lines('LOGIN_FAILED'))

    def test_aws_login_failure_is_audited(self):
        self._write_workspace(sso=SSO_AWS)
        self.fail_commands.add('aws sso login')
        with contextlib.redirect_stdout(io.StringIO()), \
                contextlib.redirect_stderr(io.StringIO()):
            ok = self._session_manager().login('aws')

        self.assertFalse(ok)
        self.assertTrue(self._audit_lines('LOGIN_FAILED'))
        self.assertFalse(self._audit_lines('| LOGIN |'))

    def test_azure_login_applies_tenant_and_subscription_bindings(self):
        self._write_workspace(provider='azure', region='eastus',
                              azure_tenant='my-tenant-id',
                              azure_subscription='my-subscription-id')
        with contextlib.redirect_stdout(io.StringIO()):
            ok = self._session_manager().login('azure')

        self.assertTrue(ok)
        cmd, kwargs = self._find_call('az', 'login')
        self.assertEqual(cmd, ['az', 'login', '--use-device-code',
                               '--tenant', 'my-tenant-id'])
        self.assertEqual(kwargs['env']['AZURE_CONFIG_DIR'],
                         str(self._providers_dir() / 'azure'))
        set_cmd, _ = self._find_call('az', 'account', 'set')
        self.assertEqual(set_cmd, ['az', 'account', 'set',
                                   '--subscription', 'my-subscription-id'])

    def test_gcp_login_applies_impersonation_and_project(self):
        self._write_workspace(
            provider='gcp', account_id='my-project', region='us-central1',
            gcp_impersonate_service_account='sa@my-project.iam.gserviceaccount.com')
        with contextlib.redirect_stdout(io.StringIO()):
            ok = self._session_manager().login('gcp')

        self.assertTrue(ok)
        cmd, kwargs = self._find_call('gcloud', 'auth', 'login')
        self.assertIsNotNone(cmd)
        self.assertEqual(kwargs['env']['CLOUDSDK_CONFIG'],
                         str(self._providers_dir() / 'gcloud'))
        imp_cmd, _ = self._find_call('gcloud', 'config', 'set',
                                     'auth/impersonate_service_account')
        self.assertEqual(imp_cmd[-1], 'sa@my-project.iam.gserviceaccount.com')
        proj_cmd, _ = self._find_call('gcloud', 'config', 'set', 'project')
        self.assertEqual(proj_cmd[-1], 'my-project')


class TestSessionMetadata(ModernAuthTestCase):

    def test_login_records_identity_and_expiry(self):
        self._write_workspace(sso=SSO_AWS)
        expires = (datetime.now(timezone.utc)
                   + timedelta(hours=8)).strftime('%Y-%m-%dT%H:%M:%SZ')
        cache_dir = self._providers_dir() / 'aws' / 'sso' / 'cache'
        cache_dir.mkdir(parents=True, exist_ok=True)
        (cache_dir / 'abc123.json').write_text(
            json.dumps({'expiresAt': expires, 'accessToken': 'fake'}))

        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().login('aws')

        session = self._read_workspace()['sessions']['aws']
        self.assertEqual(session['mode'], 'sso')
        self.assertEqual(session['identity'],
                         'arn:aws:sts::123456789012:assumed-role/Dev/user')
        self.assertEqual(session['expires_at'], expires)
        self.assertTrue(self._audit_lines('| LOGIN | session/aws |'))

    def test_no_token_material_in_workspace_config_or_audit_log(self):
        self._write_workspace(sso=SSO_AWS)
        cache_dir = self._providers_dir() / 'aws' / 'sso' / 'cache'
        cache_dir.mkdir(parents=True, exist_ok=True)
        (cache_dir / 'abc123.json').write_text(
            json.dumps({'expiresAt': '2099-01-01T00:00:00Z',
                        'accessToken': 'SECRET-TOKEN-VALUE'}))

        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().login('aws')

        ws_raw = (self.workspace_dir / f"{WS_ID}.json").read_text()
        self.assertNotIn('SECRET-TOKEN-VALUE', ws_raw)
        self.assertNotIn('SECRET-TOKEN-VALUE', self.audit_log.read_text())

    def test_logout_clears_session_and_audits(self):
        self._write_workspace(
            sso=SSO_AWS,
            sessions={'aws': {'mode': 'sso', 'identity': 'x',
                              'expires_at': None,
                              'logged_in_at': '2026-07-20T00:00:00+00:00'}})
        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().logout('aws')

        self.assertNotIn('aws', self._read_workspace().get('sessions', {}))
        cmd, _ = self._find_call('aws', 'sso', 'logout')
        self.assertIsNotNone(cmd, "aws sso logout not invoked")
        self.assertTrue(self._audit_lines('| LOGOUT | session/aws |'))


class TestSsoConfigStorage(ModernAuthTestCase):

    def test_setup_stores_nonsecret_config_in_workspace_config(self):
        self._write_workspace()
        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().setup('aws', {
                'sso_start_url': 'https://acme.awsapps.com/start',
                'sso_region': 'us-east-1',
                'sso_account_id': '123456789012',
                'sso_role_name': 'DevAccess',
            })

        workspace = self._read_workspace()
        self.assertEqual(workspace['sso']['aws'], SSO_AWS['aws'])
        # Never in the pass vault: no pass invocations, no store writes
        self.assertIsNone(self._find_call('pass')[0])
        self.assertFalse(
            (Path(self.tmp_home) / '.password-store').exists())
        self.assertTrue(self._audit_lines('SSO_SETUP'))

    def test_setup_generates_scoped_aws_config_with_sso_precedence(self):
        self._write_workspace()
        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().setup('aws', {
                'sso_start_url': 'https://acme.awsapps.com/start',
                'sso_region': 'us-east-1',
            })

        config = (self._providers_dir() / 'aws' / 'config').read_text()
        self.assertIn('[sso-session nubifer]', config)
        default_section = config.split('\n[default]\n')[1].split('[profile')[0]
        self.assertIn('sso_session = nubifer', default_section)
        self.assertNotIn('credential_process', default_section)
        # Static credential_process remains as the documented fallback
        self.assertIn('[profile nubifer-static]', config)
        self.assertIn('credential_process = '
                      '/usr/local/bin/nubifer-aws-credential-helper', config)

    def test_setup_role_arn_generates_role_assumption_profile(self):
        self._write_workspace()
        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().setup('aws', {
                'sso_start_url': 'https://acme.awsapps.com/start',
                'role_arn': 'arn:aws:iam::123456789012:role/Deployer',
            })

        workspace = self._read_workspace()
        self.assertEqual(workspace['aws_role_arn'],
                         'arn:aws:iam::123456789012:role/Deployer')
        config = (self._providers_dir() / 'aws' / 'config').read_text()
        default_section = config.split('\n[default]\n')[1].split('[profile')[0]
        self.assertIn('role_arn = arn:aws:iam::123456789012:role/Deployer',
                      default_section)
        self.assertIn('source_profile = nubifer-sso', default_section)

    def test_setup_azure_stores_tenant_and_subscription(self):
        self._write_workspace(provider='azure', region='eastus')
        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().setup('azure', {
                'tenant': 'my-tenant-id',
                'subscription': 'my-subscription-id',
            })

        workspace = self._read_workspace()
        self.assertEqual(workspace['azure_tenant'], 'my-tenant-id')
        self.assertEqual(workspace['azure_subscription'], 'my-subscription-id')

    def test_setup_gcp_stores_impersonation_and_writes_gcloud_config(self):
        self._write_workspace(provider='gcp', account_id='my-project',
                              region='us-central1')
        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().setup('gcp', {
                'impersonate_service_account':
                    'sa@my-project.iam.gserviceaccount.com',
            })

        workspace = self._read_workspace()
        self.assertEqual(workspace['gcp_impersonate_service_account'],
                         'sa@my-project.iam.gserviceaccount.com')
        gcloud_config = (self._providers_dir() / 'gcloud' / 'configurations'
                         / 'config_default')
        self.assertIn('impersonate_service_account = '
                      'sa@my-project.iam.gserviceaccount.com',
                      gcloud_config.read_text())

    def test_setup_never_overwrites_user_edited_aws_config(self):
        self._write_workspace()
        config_path = self._providers_dir() / 'aws' / 'config'
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text('# user-managed\n[default]\nregion = eu-west-1\n')

        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().setup('aws', {
                'sso_start_url': 'https://acme.awsapps.com/start',
            })

        self.assertIn('user-managed', config_path.read_text())

    def test_setup_with_no_options_fails(self):
        self._write_workspace()
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                self._session_manager().setup('aws', {})


class TestStatus(ModernAuthTestCase):

    def test_status_none_when_nothing_configured(self):
        self._write_workspace()
        rows = self._status_json()['providers']
        for provider in ('aws', 'azure', 'gcp'):
            self.assertEqual(rows[provider]['mode'], 'none')

    def test_status_static_mode_from_vault_profiles(self):
        self._write_workspace()
        self._plant_static_creds('aws', 'default')
        rows = self._status_json()['providers']
        self.assertEqual(rows['aws']['mode'], 'static')
        self.assertEqual(rows['aws']['identity'], 'default')
        self.assertEqual(rows['azure']['mode'], 'none')

    def test_status_sso_mode_with_active_session(self):
        expires = (datetime.now(timezone.utc)
                   + timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%SZ')
        self._write_workspace(
            sso=SSO_AWS,
            sessions={'aws': {'mode': 'sso',
                              'identity': 'arn:aws:sts::123:assumed-role/Dev',
                              'expires_at': expires,
                              'logged_in_at': '2026-07-20T00:00:00+00:00'}})
        rows = self._status_json()['providers']
        self.assertEqual(rows['aws']['mode'], 'sso')
        self.assertEqual(rows['aws']['state'], 'active')
        self.assertEqual(rows['aws']['identity'],
                         'arn:aws:sts::123:assumed-role/Dev')

    def test_status_sso_takes_precedence_over_static(self):
        """Req 4.2: SSO wins when both exist; static shown as fallback."""
        self._write_workspace(
            sso=SSO_AWS,
            sessions={'aws': {'mode': 'sso', 'identity': 'x',
                              'expires_at': None,
                              'logged_in_at': '2026-07-20T00:00:00+00:00'}})
        self._plant_static_creds('aws', 'default')

        rows = self._status_json()['providers']
        self.assertEqual(rows['aws']['mode'], 'sso')
        self.assertTrue(rows['aws']['static_fallback'])

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self._session_manager().status()
        output = buf.getvalue()
        self.assertIn('sso (static fallback)', output)
        self.assertIn('Resolution order: SSO session > static', output)

    def test_status_expired_session_audited_once_with_relogin_hint(self):
        self._write_workspace(
            sso=SSO_AWS,
            sessions={'aws': {'mode': 'sso', 'identity': 'x',
                              'expires_at': '2026-07-19T00:00:00Z',
                              'logged_in_at': '2026-07-18T00:00:00+00:00'}})

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self._session_manager().status()
        output = buf.getvalue()
        self.assertIn('EXPIRED', output)
        self.assertIn('nubifer-creds login -t aws', output)

        # Second status must not duplicate the expiry audit event
        with contextlib.redirect_stdout(io.StringIO()):
            self._session_manager().status()
        self.assertEqual(len(self._audit_lines('SESSION_EXPIRED')), 1)

    def test_status_sso_configured_but_not_logged_in(self):
        self._write_workspace(sso=SSO_AWS)
        rows = self._status_json()['providers']
        self.assertEqual(rows['aws']['mode'], 'sso')
        self.assertEqual(rows['aws']['state'], 'not logged in')


class TestCliDispatch(ModernAuthTestCase):

    def test_status_command_works_without_pass_store(self):
        """Session commands must not require an initialized pass vault."""
        self._write_workspace()
        self.assertFalse((Path(self.tmp_home) / '.password-store').exists())

        buf = io.StringIO()
        with mock.patch.object(sys, 'argv',
                               ['nubifer-creds', 'status', '--json',
                                '-w', WS_ID]):
            with contextlib.redirect_stdout(buf):
                nc.main()
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload['workspace_id'], WS_ID)

    def test_login_command_requires_provider(self):
        self._write_workspace()
        with mock.patch.object(sys, 'argv',
                               ['nubifer-creds', 'login', '-w', WS_ID]):
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as ctx:
                    nc.main()
        self.assertEqual(ctx.exception.code, 1)

    def test_login_setup_cli_stores_configuration(self):
        self._write_workspace()
        argv = ['nubifer-creds', 'login', 'setup', '-t', 'aws', '-w', WS_ID,
                '--sso-start-url', 'https://acme.awsapps.com/start',
                '--sso-region', 'us-east-1']
        with mock.patch.object(sys, 'argv', argv):
            with contextlib.redirect_stdout(io.StringIO()):
                nc.main()
        self.assertEqual(
            self._read_workspace()['sso']['aws']['sso_start_url'],
            'https://acme.awsapps.com/start')


if __name__ == '__main__':
    unittest.main()
