#!/usr/bin/env python3
"""
Offline unit tests for read-only mode enforcement in the oci and terraform
CLI wrappers (GitHub issues #7 and #8).

Enforcement models under test:
- oci: verb blocklist — any argument matching a write verb (create, delete,
  update, terminate, launch, put, copy, ...) with word boundaries blocks the
  command; read verbs (list, get) pass through
- terraform: subcommand blocklist — apply (without an existing saved plan
  file), destroy, import, taint, untaint, and state rm/mv/push/
  replace-provider are blocked; plan, show, validate, state list/show/pull
  pass through. 'terraform apply <planfile>' is allowed by design
  (pre-approved plan).

For EACH wrapper:
  (a) write operation in a read-only workspace exits nonzero with the
      WRITE BLOCKED message and the real CLI is never invoked
  (b) the same write passes through in a read-write workspace
  (c) a read operation passes through even in read-only mode
  (d) enforcement fires before any credential/config resolution — a blocked
      run leaves no side effects (no CLI invocation, no files created)

Plus regression tests for enforcement bugs fixed alongside this suite:
- oci: 'os object put/copy/sync/rename/bulk-upload' previously slipped
  through (put/copy/upload/sync/rename/reencrypt missing from verb list)
- terraform: 'state rm/mv/push/replace-provider' previously slipped through
  (only the first subcommand 'state' was inspected)
- terraform: 'apply -var foo=bar' was previously treated as
  'apply <planfile>' and slipped through (flag value mistaken for a plan)

Same offline harness pattern as test_wrapper_sso.py: each test runs a temp
copy of the wrapper with the hardcoded real-CLI location substituted for a
recorder stub — no real oci/terraform binary, no network, isolated temp
HOME. Stdlib only.
"""

import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

WRAPPER_DIR = Path(__file__).resolve().parent.parent / 'cli-wrappers'

WORKSPACE_ID = 'ws-test-1234'
WORKSPACE_NAME = 'alpha'

RECORDER_STUB = """#!/bin/bash
# Test stub standing in for the real provider CLI binary
echo "ARGS: $*" > "$NUBIFER_TEST_RECORD"
exit 0
"""


def _tree(root):
    """Sorted list of all paths under root (side-effect snapshot)."""
    return sorted(str(p) for p in Path(root).rglob('*'))


class ReadOnlyWrapperTestBase(unittest.TestCase):
    """Isolated HOME + stubbed real CLI binary for wrapper runs."""

    provider = 'oci'  # wrapper filename, overridden per subclass

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='nubifer-ro-wrapper-test-'))
        self.home = self.tmp / 'home'
        self.stub_bin = self.tmp / 'bin'
        self.work = self.tmp / 'work'          # cwd for wrapper runs
        self.record = self.tmp / 'record.txt'
        self.home.mkdir()
        self.stub_bin.mkdir()
        self.work.mkdir()

        # Recorder stub replaces the hardcoded real CLI
        self.cli_stub = self.stub_bin / self.stub_name()
        self.cli_stub.write_text(RECORDER_STUB)
        self._make_executable(self.cli_stub)

        # Temp copy of the wrapper with the real-CLI location substituted
        self.wrapper = self.tmp / self.provider
        self.wrapper.write_text(
            self.substitute(( WRAPPER_DIR / self.provider).read_text()))
        self._make_executable(self.wrapper)

        # Workspace config JSON (wrappers key off env vars; the config file
        # keeps the environment realistic, matching test_wrapper_sso.py)
        workspace_dir = self.home / '.config' / 'nubifer' / 'workspaces'
        workspace_dir.mkdir(parents=True)
        (workspace_dir / f'{WORKSPACE_ID}.json').write_text(json.dumps({
            'id': WORKSPACE_ID,
            'name': WORKSPACE_NAME,
            'provider': self.provider,
            'read_only': True,
        }))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    # -- per-provider hooks ----------------------------------------------

    def stub_name(self):
        return f'{self.provider}-real'

    def substitute(self, source):
        raise NotImplementedError

    # -- helpers ---------------------------------------------------------

    @staticmethod
    def _make_executable(path):
        path.chmod(path.stat().st_mode | stat.S_IXUSR)

    def run_wrapper(self, args, read_only=True):
        env = {
            'PATH': f"{self.stub_bin}:{os.environ.get('PATH', '')}",
            'HOME': str(self.home),
            'NUBIFER_WORKSPACE_ID': WORKSPACE_ID,
            'NUBIFER_WORKSPACE_NAME': WORKSPACE_NAME,
            'NUBIFER_TEST_RECORD': str(self.record),
        }
        if read_only:
            env['NUBIFER_WORKSPACE_READ_ONLY'] = 'true'
        return subprocess.run(
            ['/bin/bash', str(self.wrapper)] + args,
            env=env, cwd=str(self.work),
            capture_output=True, text=True, timeout=60)

    def recorded(self):
        self.assertTrue(self.record.is_file(),
                        'real CLI stub was never invoked')
        return self.record.read_text()

    def assert_not_invoked(self):
        self.assertFalse(self.record.is_file(),
                         'real CLI stub must not run')

    def assert_blocked(self, result):
        self.assertEqual(result.returncode, 1,
                         f'expected blocked exit 1: {result.stderr}')
        self.assertIn('WRITE BLOCKED', result.stderr)
        self.assertIn('read-only mode', result.stderr)
        self.assert_not_invoked()

    def assert_passed_through(self, result, args):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('WRITE BLOCKED', result.stderr)
        self.assertEqual(self.recorded().strip(), f"ARGS: {' '.join(args)}")

    def assert_no_side_effects(self, run):
        """(d) blocked run creates nothing: no CLI call, no new files."""
        home_before = _tree(self.home)
        work_before = _tree(self.work)
        result = run()
        self.assert_blocked(result)
        self.assertEqual(_tree(self.home), home_before,
                         'blocked run must not create files in HOME')
        self.assertEqual(_tree(self.work), work_before,
                         'blocked run must not create files in cwd')
        return result


class TestOciReadOnly(ReadOnlyWrapperTestBase):
    """oci wrapper: write-verb blocklist (issue #7)."""

    provider = 'oci'

    def substitute(self, source):
        # oci wrapper hardcodes the real CLI at /usr/local/bin/oci
        self.assertIn('/usr/local/bin/oci', source)
        return source.replace('/usr/local/bin/oci', str(self.cli_stub))

    # (a) write blocked in read-only
    def test_write_verbs_blocked_in_read_only(self):
        for args in (
                ['compute', 'instance', 'terminate',
                 '--instance-id', 'ocid1.instance.oc1..x'],
                ['os', 'bucket', 'create', '--name', 'b'],
                ['compute', 'instance', 'launch', '--shape', 'VM.Standard2.1'],
                ['iam', 'user', 'delete', '--user-id', 'ocid1.user.oc1..x'],
                ['db', 'system', 'update', '--db-system-id', 'ocid1..x']):
            with self.subTest(args=args):
                result = self.run_wrapper(args)
                self.assert_blocked(result)
                self.assertIn(f"oci {' '.join(args)}", result.stderr)
                self.record.unlink(missing_ok=True)

    def test_block_message_shows_rw_escape_hatch(self):
        result = self.run_wrapper(['os', 'bucket', 'create', '--name', 'b'])
        self.assert_blocked(result)
        self.assertIn(f'sudo nubifer-workspace rw {WORKSPACE_ID}',
                      result.stderr)

    # (b) same write passes through read-write
    def test_write_passes_through_in_read_write(self):
        args = ['compute', 'instance', 'terminate',
                '--instance-id', 'ocid1.instance.oc1..x']
        self.assert_passed_through(
            self.run_wrapper(args, read_only=False), args)

    # (c) reads pass through even in read-only
    def test_reads_pass_through_in_read_only(self):
        for args in (
                ['compute', 'instance', 'list',
                 '--compartment-id', 'ocid1.compartment.oc1..x'],
                ['os', 'object', 'list', '--bucket-name', 'b'],
                ['iam', 'region', 'list'],
                ['os', 'object', 'get', '--bucket-name', 'b',
                 '--name', 'k']):
            with self.subTest(args=args):
                self.assert_passed_through(self.run_wrapper(args), args)
                self.record.unlink()

    # (d) enforcement before any credential/config resolution
    def test_blocked_write_has_no_side_effects(self):
        # The block must fire before the wrapper touches anything: no real
        # CLI call, no ~/.oci config resolution, nothing written anywhere
        self.assert_no_side_effects(lambda: self.run_wrapper(
            ['compute', 'instance', 'terminate', '--instance-id', 'x']))

    # regression: object-storage write verbs previously missing
    def test_object_storage_write_verbs_blocked(self):
        for args in (
                ['os', 'object', 'put', '--bucket-name', 'b',
                 '--file', 'f.txt'],
                ['os', 'object', 'copy', '--bucket-name', 'b',
                 '--source-object-name', 'a', '--destination-bucket', 'c'],
                ['os', 'object', 'sync', '--bucket-name', 'b',
                 '--src-dir', '.'],
                ['os', 'object', 'rename', '--bucket-name', 'b',
                 '--source-name', 'a', '--new-name', 'c'],
                ['os', 'object', 'bulk-upload', '--bucket-name', 'b',
                 '--src-dir', '.'],
                ['os', 'object', 'bulk-delete', '--bucket-name', 'b']):
            with self.subTest(args=args):
                self.assert_blocked(self.run_wrapper(args))


class TestTerraformReadOnly(ReadOnlyWrapperTestBase):
    """terraform wrapper: subcommand blocklist (issue #8)."""

    provider = 'terraform'

    def stub_name(self):
        # The wrapper searches candidate dirs for a binary named 'terraform'
        return 'terraform'

    def substitute(self, source):
        # terraform wrapper discovers the real binary via a dir search list
        search = 'for dir in /usr/bin /usr/local/bin /snap/bin; do'
        self.assertIn(search, source)
        return source.replace(search, f'for dir in {self.stub_bin}; do')

    # (a) writes blocked in read-only
    def test_apply_blocked_in_read_only(self):
        for args in (['apply'], ['apply', '-auto-approve']):
            with self.subTest(args=args):
                result = self.run_wrapper(args)
                self.assert_blocked(result)
                # Actionable hint toward the allowed workflow
                self.assertIn('terraform plan -out=tfplan', result.stderr)
                self.assertIn(f"terraform {' '.join(args)}", result.stderr)

    def test_destroy_import_taint_untaint_blocked(self):
        for args in (
                ['destroy'],
                ['destroy', '-auto-approve'],
                ['import', 'aws_instance.web', 'i-123'],
                ['taint', 'aws_instance.web'],
                ['untaint', 'aws_instance.web']):
            with self.subTest(args=args):
                result = self.run_wrapper(args)
                self.assert_blocked(result)
                self.assertIn(f'sudo nubifer-workspace rw {WORKSPACE_ID}',
                              result.stderr)

    def test_global_flags_before_subcommand_still_blocked(self):
        # Subcommand detection must skip leading flags like -chdir=...
        self.assert_blocked(
            self.run_wrapper(['-chdir=envs/prod', 'destroy']))

    # (b) same writes pass through read-write
    def test_writes_pass_through_in_read_write(self):
        for args in (['apply', '-auto-approve'], ['destroy'],
                     ['state', 'rm', 'aws_instance.web']):
            with self.subTest(args=args):
                self.assert_passed_through(
                    self.run_wrapper(args, read_only=False), args)
                self.record.unlink()

    # (c) reads pass through even in read-only
    def test_reads_pass_through_in_read_only(self):
        for args in (['plan'], ['plan', '-out=tfplan'], ['validate'],
                     ['show'], ['output'], ['version'],
                     ['state', 'list'],
                     ['state', 'show', 'aws_instance.web'],
                     ['state', 'pull']):
            with self.subTest(args=args):
                self.assert_passed_through(self.run_wrapper(args), args)
                self.record.unlink()

    def test_apply_with_saved_plan_allowed_by_design(self):
        # Documented exception: a pre-approved saved plan may be applied
        (self.work / 'tfplan').write_bytes(b'not-a-real-plan')
        args = ['apply', 'tfplan']
        self.assert_passed_through(self.run_wrapper(args), args)

    # (d) enforcement before any credential/config resolution
    def test_blocked_write_has_no_side_effects(self):
        # No .terraform dir, no state files, no lock files — the block
        # fires before terraform (or any backend/credential code) runs
        self.assert_no_side_effects(
            lambda: self.run_wrapper(['apply', '-auto-approve']))

    # regression: state-mutating subcommands previously slipped through
    def test_state_mutations_blocked(self):
        for args in (
                ['state', 'rm', 'aws_instance.web'],
                ['state', 'mv', 'aws_instance.a', 'aws_instance.b'],
                ['state', 'push', 'errored.tfstate'],
                ['state', 'replace-provider',
                 'hashicorp/aws', 'registry.example.com/aws']):
            with self.subTest(args=args):
                result = self.run_wrapper(args)
                self.assert_blocked(result)
                self.assertIn(f'terraform state {args[1]}', result.stderr)

    # regression: flag values previously mistaken for saved plan files
    def test_apply_with_flag_value_is_not_a_saved_plan(self):
        # 'foo=bar' is the value of -var, not a plan file — must block
        self.assert_blocked(
            self.run_wrapper(['apply', '-var', 'foo=bar']))

    def test_apply_with_nonexistent_plan_file_blocked(self):
        # Fail-safe: only an existing file counts as a pre-approved plan
        self.assert_blocked(self.run_wrapper(['apply', 'no-such-plan']))


if __name__ == '__main__':
    unittest.main()
