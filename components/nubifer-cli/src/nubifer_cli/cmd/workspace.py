#!/usr/bin/env python3
"""Workspace management subcommand."""

from typing import Optional
import subprocess
import sys
import typer

app = typer.Typer(
    help="Manage cloud workspaces (alias: ws)",
    no_args_is_help=True,
)


def _run_workspace_script(args: list[str]) -> int:
    """Delegate to existing nubifer-workspace script."""
    try:
        result = subprocess.run(
            ["nubifer-workspace"] + args,
            check=False,
        )
        return result.returncode
    except FileNotFoundError:
        typer.echo("✗ nubifer-workspace script not found", err=True)
        return 1


@app.command("create")
def create(
    name: str = typer.Option(..., "-n", "--name", help="Workspace name"),
    provider: str = typer.Option(..., "-p", "--provider", help="Cloud provider (aws/azure/gcp/oracle)"),
    region: str = typer.Option(..., "-r", "--region", help="Default region"),
    account_id: str = typer.Option(..., "-a", "--account-id", help="Account ID"),
    read_only: bool = typer.Option(False, "--read-only", help="Create in read-only mode"),
    yes: bool = typer.Option(False, "-y", "--yes", help="Skip confirmation"),
) -> None:
    """Create a new workspace."""
    args = ["create", "-n", name, "-p", provider, "-r", region, "-a", account_id]
    if read_only:
        args.append("--read-only")
    if yes:
        args.append("-y")
    sys.exit(_run_workspace_script(args))


@app.command("list")
def list_workspaces(
    provider: Optional[str] = typer.Option(None, "-p", "--provider", help="Filter by provider"),
) -> None:
    """List all workspaces."""
    args = ["list"]
    if provider:
        args.extend(["-p", provider])
    sys.exit(_run_workspace_script(args))


@app.command("switch")
def switch(
    workspace_id: str = typer.Argument(..., help="Workspace ID or name"),
) -> None:
    """Switch to a workspace."""
    sys.exit(_run_workspace_script(["switch", workspace_id]))


@app.command("current")
def current() -> None:
    """Show current workspace."""
    sys.exit(_run_workspace_script(["current"]))


@app.command("delete")
def delete(
    workspace_id: str = typer.Argument(..., help="Workspace ID"),
    yes: bool = typer.Option(False, "-y", "--yes", help="Skip confirmation"),
) -> None:
    """Delete a workspace."""
    args = ["delete", workspace_id]
    if yes:
        args.append("-y")
    sys.exit(_run_workspace_script(args))


@app.command("env")
def env(
    workspace_id: str = typer.Argument(..., help="Workspace ID"),
) -> None:
    """Export environment variables for workspace (non-credential vars only)."""
    sys.exit(_run_workspace_script(["env", workspace_id]))


@app.command("ro")
def read_only(
    workspace_id: Optional[str] = typer.Argument(None, help="Workspace ID (defaults to current)"),
) -> None:
    """Enable read-only mode (lock workspace)."""
    args = ["ro"]
    if workspace_id:
        args.append(workspace_id)
    sys.exit(_run_workspace_script(args))


@app.command("rw")
def read_write(
    workspace_id: Optional[str] = typer.Argument(None, help="Workspace ID (defaults to current)"),
    duration: int = typer.Option(0, "-d", "--duration", help="Auto-revert to read-only after N minutes"),
) -> None:
    """Enable read-write mode (requires confirmation)."""
    args = ["rw"]
    if workspace_id:
        args.append(workspace_id)
    if duration > 0:
        args.extend(["-d", str(duration)])
    sys.exit(_run_workspace_script(args))
