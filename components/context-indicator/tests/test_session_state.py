#!/usr/bin/env python3
"""Tests for the Context Indicator session-state display (Req 5.2).

The GNOME Shell extension itself cannot run here, so coverage is split:

* Always-on offline checks: metadata.json validity, expected exports in
  sessionState.js, install script includes the new module.
* gjs-backed checks (skipped when gjs is absent, e.g. minimal CI images):
  syntax-parse extension.js, and drive the pure sessionState.js helpers
  with real inputs via standalone gjs.

gjs runs are local-only (no network); TZ is pinned to UTC so expected
HH:MM values are deterministic.
"""

import json
import os
import shutil
import subprocess
import unittest
from datetime import datetime, timezone
from pathlib import Path

COMPONENT_DIR = Path(__file__).resolve().parent.parent
EXT_DIR = COMPONENT_DIR / 'gnome-extension'

GJS = shutil.which('gjs')

# Fixed "now": 2026-07-20 12:00:00 UTC
NOW_MS = int(datetime(2026, 7, 20, 12, 0, 0,
                      tzinfo=timezone.utc).timestamp() * 1000)


def _run_gjs(script, timeout=30):
    env = dict(os.environ)
    env['TZ'] = 'UTC'
    return subprocess.run(
        [GJS, '-c', script],
        capture_output=True, text=True, timeout=timeout, env=env)


def _compute(sessions, now_ms=NOW_MS):
    """Run computeSessionStates()/worstSessionState() in standalone gjs."""
    payload = json.dumps({'sessions': sessions, 'now': now_ms})
    script = f'''
        imports.searchPath.unshift({json.dumps(str(EXT_DIR))});
        const S = imports.sessionState;
        const input = JSON.parse({json.dumps(payload)});
        const states = S.computeSessionStates(input.sessions, input.now);
        print(JSON.stringify({{
            states: states,
            worst: S.worstSessionState(states),
        }}));
    '''
    result = _run_gjs(script)
    if result.returncode != 0:
        raise AssertionError(f"gjs failed: {result.stderr}")
    return json.loads(result.stdout.strip())


class TestOfflineArtifacts(unittest.TestCase):
    """Checks that run everywhere, no gjs required."""

    def test_metadata_json_is_valid(self):
        with open(EXT_DIR / 'metadata.json') as f:
            meta = json.load(f)
        self.assertEqual(meta['uuid'], 'nubiferos-context@nubiferos.org')
        self.assertIn('shell-version', meta)

    def test_session_state_module_exports(self):
        src = (EXT_DIR / 'sessionState.js').read_text()
        for name in ('parseExpiry', 'sessionState', 'computeSessionStates',
                     'worstSessionState', 'formatExpiryTime',
                     'EXPIRING_SOON_SECONDS'):
            self.assertIn(name, src, f"missing export: {name}")
        # Must stay free of GNOME Shell imports for standalone gjs testing
        self.assertNotIn('imports.ui', src)
        self.assertNotIn('imports.gi', src)

    def test_extension_uses_session_module_defensively(self):
        src = (EXT_DIR / 'extension.js').read_text()
        # Module load is wrapped so a missing file disables the feature
        # instead of crashing GNOME Shell
        self.assertIn('let SessionState = null;', src)
        self.assertIn('_rebuildSessionSection', src)
        self.assertIn('_updateSessionHint', src)

    def test_install_script_copies_session_module(self):
        src = (COMPONENT_DIR / 'install-indicator.sh').read_text()
        self.assertIn('sessionState.js', src)


@unittest.skipUnless(GJS, "gjs not installed")
class TestGjsSyntax(unittest.TestCase):
    """Parse extension sources with the real gjs engine (no execution)."""

    def _syntax_check(self, filename):
        path = str(EXT_DIR / filename)
        # new Function() parses the source as a function body without
        # running it, so imports.ui etc. are never dereferenced.
        script = f'''
            const [ok, bytes] = imports.gi.GLib.file_get_contents(
                {json.dumps(path)});
            new Function(imports.byteArray.toString(bytes));
            print('SYNTAX_OK');
        '''
        result = _run_gjs(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('SYNTAX_OK', result.stdout)

    def test_extension_js_parses(self):
        self._syntax_check('extension.js')

    def test_session_state_js_parses(self):
        self._syntax_check('sessionState.js')


@unittest.skipUnless(GJS, "gjs not installed")
class TestComputeSessionStates(unittest.TestCase):

    def test_active_session_with_expiry(self):
        out = _compute({'aws': {
            'mode': 'sso',
            'identity': 'arn:aws:sts::123456789012:assumed-role/Dev/user',
            'expires_at': '2026-07-20T14:00:00Z',
        }})
        self.assertEqual(len(out['states']), 1)
        s = out['states'][0]
        self.assertEqual(s['provider'], 'aws')
        self.assertEqual(s['state'], 'active')
        self.assertEqual(s['expiresHHMM'], '14:00')  # TZ=UTC
        self.assertEqual(s['mode'], 'sso')
        self.assertIsNone(out['worst'])

    def test_expiring_soon_under_15_minutes(self):
        out = _compute({'azure': {
            'mode': 'sso',
            'expires_at': '2026-07-20T12:10:00Z',
        }})
        self.assertEqual(out['states'][0]['state'], 'expiring')
        self.assertEqual(out['states'][0]['expiresHHMM'], '12:10')
        self.assertEqual(out['worst'], 'expiring')

    def test_exactly_15_minutes_is_still_active(self):
        out = _compute({'aws': {'expires_at': '2026-07-20T12:15:00Z'}})
        self.assertEqual(out['states'][0]['state'], 'active')

    def test_expired_session(self):
        out = _compute({'gcp': {
            'mode': 'sso',
            'expires_at': '2026-07-20T11:59:00Z',
        }})
        self.assertEqual(out['states'][0]['state'], 'expired')
        self.assertEqual(out['worst'], 'expired')

    def test_expired_beats_expiring_for_hint(self):
        out = _compute({
            'aws': {'expires_at': '2026-07-20T12:05:00Z'},   # expiring
            'gcp': {'expires_at': '2026-07-20T11:00:00Z'},   # expired
        })
        self.assertEqual(out['worst'], 'expired')

    def test_missing_expiry_counts_as_active(self):
        # Mirrors nubifer-creds status: no parseable expiry -> active
        out = _compute({'azure': {'mode': 'sso', 'identity': 'user@x.io',
                                  'expires_at': None}})
        s = out['states'][0]
        self.assertEqual(s['state'], 'active')
        self.assertIsNone(s['expiresHHMM'])

    def test_garbage_expiry_counts_as_active(self):
        out = _compute({'aws': {'expires_at': 'not-a-timestamp'}})
        self.assertEqual(out['states'][0]['state'], 'active')
        self.assertIsNone(out['states'][0]['expiresHHMM'])

    def test_naive_timestamp_treated_as_utc(self):
        # nubifer-creds treats timestamps without a zone as UTC
        out = _compute({'aws': {'expires_at': '2026-07-20T13:30:00'}})
        self.assertEqual(out['states'][0]['state'], 'active')
        self.assertEqual(out['states'][0]['expiresHHMM'], '13:30')

    def test_utc_suffix_and_space_separator(self):
        # gcloud-style "YYYY-MM-DD HH:MM:SS UTC"
        out = _compute({'gcp': {'expires_at': '2026-07-20 13:30:00 UTC'}})
        self.assertEqual(out['states'][0]['state'], 'active')
        self.assertEqual(out['states'][0]['expiresHHMM'], '13:30')

    def test_provider_ordering_aws_azure_gcp(self):
        out = _compute({
            'gcp': {'expires_at': '2026-07-20T14:00:00Z'},
            'aws': {'expires_at': '2026-07-20T14:00:00Z'},
            'azure': {'expires_at': '2026-07-20T14:00:00Z'},
        })
        self.assertEqual([s['provider'] for s in out['states']],
                         ['aws', 'azure', 'gcp'])

    def test_default_mode_is_sso(self):
        out = _compute({'aws': {'expires_at': '2026-07-20T14:00:00Z'}})
        self.assertEqual(out['states'][0]['mode'], 'sso')


@unittest.skipUnless(GJS, "gjs not installed")
class TestMalformedInput(unittest.TestCase):
    """Missing/malformed sessions metadata must yield nothing, never throw."""

    def test_sessions_missing(self):
        self.assertEqual(_compute(None)['states'], [])

    def test_sessions_is_string(self):
        self.assertEqual(_compute('oops')['states'], [])

    def test_sessions_is_number(self):
        self.assertEqual(_compute(42)['states'], [])

    def test_sessions_is_array(self):
        self.assertEqual(_compute([{'expires_at': 'x'}])['states'], [])

    def test_session_entry_is_string(self):
        out = _compute({'aws': 'not-an-object'})
        self.assertEqual(out['states'], [])
        self.assertIsNone(out['worst'])

    def test_session_entry_is_null(self):
        self.assertEqual(_compute({'aws': None})['states'], [])

    def test_shell_metacharacters_in_provider_key_skipped(self):
        # Provider keys feed `nubifer-creds login -t <p>`; reject junk
        out = _compute({'aws; rm -rf /': {'expires_at': '2026-07-20T10:00:00Z'}})
        self.assertEqual(out['states'], [])

    def test_unknown_but_clean_provider_key_kept(self):
        out = _compute({'oracle': {'expires_at': '2026-07-20T14:00:00Z'}})
        self.assertEqual(out['states'][0]['provider'], 'oracle')


if __name__ == '__main__':
    unittest.main()
