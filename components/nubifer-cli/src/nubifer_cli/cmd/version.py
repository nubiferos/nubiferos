#!/usr/bin/env python3
"""Version information subcommand."""

import subprocess
import sys
import typer
from rich.console import Console
from rich.table import Table

from nubifer_cli import __version__

app = typer.Typer(
    help="Show version information (alias: v)",
    invoke_without_command=True,
)

console = Console()


def _get_component_version(script: str) -> str:
    """Get version from a NubiferOS component script."""
    try:
        result = subprocess.run(
            [script, "--version"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            return result.stdout.strip().split()[-1]
        return "not installed"
    except FileNotFoundError:
        return "not installed"


@app.callback(invoke_without_command=True)
def show_version(
    ctx: typer.Context,
    verbose: bool = typer.Option(False, "-v", "--verbose", help="Show all component versions"),
) -> None:
    """Show version information."""
    if ctx.invoked_subcommand is not None:
        return
    
    if not verbose:
        console.print(f"nubifer {__version__}")
        return
    
    # Verbose output with component versions
    table = Table(title="NubiferOS Component Versions")
    table.add_column("Component", style="cyan")
    table.add_column("Version", style="green")
    
    table.add_row("nubifer-cli", __version__)
    table.add_row("Python", f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
    
    # Check component versions
    components = [
        ("nubifer-workspace", "nubifer-workspace"),
        ("nubifer-creds", "nubifer-creds"),
        ("nubifer-security-scan", "nubifer-security-scan"),
        ("nubifer-dashboard", "nubifer-dashboard"),
    ]
    
    for name, script in components:
        version = _get_component_version(script)
        table.add_row(name, version)
    
    # Check external tools
    external_tools = [
        ("grype", "grype"),
        ("lynis", "lynis"),
        ("pass", "pass"),
    ]
    
    for name, cmd in external_tools:
        version = _get_component_version(cmd)
        table.add_row(name, version)
    
    console.print(table)
