#!/usr/bin/env python3
"""NubiferOS Unified CLI - Main entry point."""

from typing import Optional
import typer
from rich.console import Console

from nubifer_cli import __version__
from nubifer_cli.cmd import workspace, creds, scan, dashboard, version, config

console = Console()

app = typer.Typer(
    name="nubifer",
    help="NubiferOS Unified CLI - Manage workspaces, credentials, and security",
    no_args_is_help=True,
    rich_markup_mode="rich",
)


def version_callback(value: bool) -> None:
    """Print version and exit."""
    if value:
        console.print(f"nubifer version {__version__}")
        raise typer.Exit()


@app.callback()
def main(
    version: Optional[bool] = typer.Option(
        None,
        "--version",
        "-V",
        callback=version_callback,
        is_eager=True,
        help="Show version and exit.",
    ),
) -> None:
    """NubiferOS Unified CLI - Manage workspaces, credentials, and security."""
    pass


# Register subcommands with their aliases
# Full command names (visible in help)
app.add_typer(workspace.app, name="workspace", help="Manage cloud workspaces (alias: ws)")
app.add_typer(creds.app, name="creds", help="Manage cloud credentials (alias: c)")
app.add_typer(scan.app, name="scan", help="Run security scans (alias: s)")
app.add_typer(dashboard.app, name="dashboard", help="Launch security dashboard (alias: d)")
app.add_typer(version.app, name="version", help="Show version information (alias: v)")
app.add_typer(config.app, name="config", help="Manage CLI configuration (alias: cfg)")

# Aliases (hidden from main help, but functional)
app.add_typer(workspace.app, name="ws", hidden=True)
app.add_typer(creds.app, name="c", hidden=True)
app.add_typer(scan.app, name="s", hidden=True)
app.add_typer(dashboard.app, name="d", hidden=True)
app.add_typer(version.app, name="v", hidden=True)
app.add_typer(config.app, name="cfg", hidden=True)


if __name__ == "__main__":
    app()
