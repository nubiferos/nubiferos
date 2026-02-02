#!/usr/bin/env python3
"""Dashboard launch subcommand."""

import subprocess
import sys
import typer

app = typer.Typer(
    help="Launch security dashboard (alias: d)",
    invoke_without_command=True,
)


@app.callback(invoke_without_command=True)
def launch(ctx: typer.Context) -> None:
    """Launch the NubiferOS security dashboard."""
    if ctx.invoked_subcommand is not None:
        return
    
    try:
        # Check if dashboard is already running
        result = subprocess.run(
            ["pgrep", "-f", "nubifer-dashboard"],
            capture_output=True,
            check=False,
        )
        
        if result.returncode == 0:
            # Dashboard is running, try to focus it
            typer.echo("ℹ Dashboard is already running, focusing window...")
            subprocess.run(
                ["wmctrl", "-a", "NubiferOS Security Dashboard"],
                check=False,
            )
            raise typer.Exit(0)
        
        # Launch dashboard
        subprocess.Popen(
            ["nubifer-dashboard"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        typer.echo("✓ Dashboard launched")
        
    except FileNotFoundError as e:
        if "nubifer-dashboard" in str(e):
            typer.echo("✗ nubifer-dashboard not found", err=True)
            typer.echo("  Install with: sudo apt install nubifer-dashboard", err=True)
        else:
            typer.echo("✗ wmctrl not found (optional, for window focus)", err=True)
        sys.exit(1)
