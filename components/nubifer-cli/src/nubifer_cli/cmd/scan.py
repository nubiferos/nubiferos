#!/usr/bin/env python3
"""Security scanning subcommand."""

from typing import Optional
import subprocess
import sys
import typer

app = typer.Typer(
    help="Run security scans (alias: s)",
    invoke_without_command=True,
)


def _run_scan_script(args: list[str]) -> int:
    """Delegate to existing nubifer-security-scan script."""
    try:
        result = subprocess.run(
            ["nubifer-security-scan"] + args,
            check=False,
        )
        return result.returncode
    except FileNotFoundError:
        typer.echo("✗ nubifer-security-scan script not found", err=True)
        return 1


@app.callback(invoke_without_command=True)
def scan_callback(
    ctx: typer.Context,
    vuln: bool = typer.Option(False, "--vuln", help="Run vulnerability scan"),
    compliance: bool = typer.Option(False, "--compliance", help="Run compliance check"),
    full: bool = typer.Option(False, "--full", help="Run all scans"),
    json_output: bool = typer.Option(False, "--json", help="Output as JSON"),
    quiet: bool = typer.Option(False, "-q", "--quiet", help="Suppress output"),
) -> None:
    """Run security scans with flags (backward compatible)."""
    if ctx.invoked_subcommand is not None:
        return
    
    # If no flags specified, show help
    if not any([vuln, compliance, full]):
        typer.echo(ctx.get_help())
        raise typer.Exit(0)
    
    args = []
    if vuln:
        args.append("--vuln")
    if compliance:
        args.append("--compliance")
    if full:
        args.append("--full")
    if json_output:
        args.append("--json")
    if quiet:
        args.append("--quiet")
    
    sys.exit(_run_scan_script(args))


@app.command("vuln")
def vuln_scan(
    target: Optional[str] = typer.Option(None, "--target", help="Scan target path"),
    json_output: bool = typer.Option(False, "--json", help="Output as JSON"),
    quiet: bool = typer.Option(False, "-q", "--quiet", help="Suppress output"),
) -> None:
    """Run vulnerability scan on installed packages."""
    args = ["--vuln"]
    if target:
        args.extend(["--target", target])
    if json_output:
        args.append("--json")
    if quiet:
        args.append("--quiet")
    sys.exit(_run_scan_script(args))


@app.command("compliance")
def compliance_scan(
    json_output: bool = typer.Option(False, "--json", help="Output as JSON"),
    quiet: bool = typer.Option(False, "-q", "--quiet", help="Suppress output"),
) -> None:
    """Run compliance/hardening audit."""
    args = ["--compliance"]
    if json_output:
        args.append("--json")
    if quiet:
        args.append("--quiet")
    sys.exit(_run_scan_script(args))


@app.command("full")
def full_scan(
    json_output: bool = typer.Option(False, "--json", help="Output as JSON"),
    quiet: bool = typer.Option(False, "-q", "--quiet", help="Suppress output"),
) -> None:
    """Run all security scans."""
    args = ["--full"]
    if json_output:
        args.append("--json")
    if quiet:
        args.append("--quiet")
    sys.exit(_run_scan_script(args))
