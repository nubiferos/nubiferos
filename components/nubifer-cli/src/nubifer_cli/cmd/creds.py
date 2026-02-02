#!/usr/bin/env python3
"""Credential management subcommand."""

from typing import Optional
import subprocess
import sys
import typer

app = typer.Typer(
    help="Manage cloud credentials (alias: c)",
    no_args_is_help=True,
)


def _run_creds_script(args: list[str]) -> int:
    """Delegate to existing nubifer-creds script."""
    try:
        result = subprocess.run(
            ["nubifer-creds"] + args,
            check=False,
        )
        return result.returncode
    except FileNotFoundError:
        typer.echo("✗ nubifer-creds script not found", err=True)
        return 1


@app.command("add")
def add(
    type: str = typer.Option(..., "-t", "--type", help="Credential type (aws/azure/gcp/api)"),
    name: str = typer.Option(..., "-n", "--name", help="Credential name"),
    workspace: Optional[str] = typer.Option(None, "-w", "--workspace", help="Target workspace"),
    yes: bool = typer.Option(False, "-y", "--yes", help="Skip confirmation"),
) -> None:
    """Add credentials to the secure store."""
    args = ["add", "-t", type, "-n", name]
    if workspace:
        args.extend(["-w", workspace])
    if yes:
        args.append("-y")
    sys.exit(_run_creds_script(args))


@app.command("list")
def list_creds(
    type: Optional[str] = typer.Option(None, "-t", "--type", help="Filter by type"),
) -> None:
    """List stored credentials."""
    args = ["list"]
    if type:
        args.extend(["-t", type])
    sys.exit(_run_creds_script(args))


@app.command("remove")
def remove(
    path: str = typer.Argument(..., help="Credential path"),
    yes: bool = typer.Option(False, "-y", "--yes", help="Skip confirmation"),
) -> None:
    """Remove a credential."""
    args = ["remove", path]
    if yes:
        args.append("-y")
    sys.exit(_run_creds_script(args))


@app.command("show")
def show(
    type: str = typer.Option(..., "-t", "--type", help="Credential type"),
    name: str = typer.Option(..., "-n", "--name", help="Credential name"),
    json_output: bool = typer.Option(False, "--json", help="Output as JSON"),
) -> None:
    """Show credential details (secrets partially masked)."""
    args = ["show", "-t", type, "-n", name]
    if json_output:
        args.append("--json")
    sys.exit(_run_creds_script(args))
