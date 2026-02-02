#!/usr/bin/env python3
"""Configuration management subcommand."""

from pathlib import Path
from typing import Optional
import typer
import yaml
from rich.console import Console
from rich.table import Table

app = typer.Typer(
    help="Manage CLI configuration (alias: cfg)",
    no_args_is_help=True,
)

console = Console()

CONFIG_DIR = Path.home() / ".config" / "nubifer"
CONFIG_FILE = CONFIG_DIR / "cli.yaml"

DEFAULT_CONFIG = {
    "default_provider": "aws",
    "default_region": "us-east-1",
    "output_format": "text",
    "color_enabled": True,
}


def _load_config() -> dict:
    """Load configuration from file."""
    if not CONFIG_FILE.exists():
        return DEFAULT_CONFIG.copy()
    
    try:
        with open(CONFIG_FILE) as f:
            config = yaml.safe_load(f) or {}
        # Merge with defaults
        return {**DEFAULT_CONFIG, **config}
    except Exception as e:
        typer.echo(f"✗ Failed to load config: {e}", err=True)
        return DEFAULT_CONFIG.copy()


def _save_config(config: dict) -> bool:
    """Save configuration to file."""
    try:
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, "w") as f:
            yaml.safe_dump(config, f, default_flow_style=False)
        return True
    except Exception as e:
        typer.echo(f"✗ Failed to save config: {e}", err=True)
        return False


@app.command("show")
def show(
    key: Optional[str] = typer.Argument(None, help="Specific config key to show"),
) -> None:
    """Show current configuration settings."""
    config = _load_config()
    
    if key:
        if key in config:
            console.print(f"{key}: {config[key]}")
        else:
            typer.echo(f"✗ Unknown config key: {key}", err=True)
            typer.echo(f"  Valid keys: {', '.join(DEFAULT_CONFIG.keys())}", err=True)
            raise typer.Exit(1)
        return
    
    table = Table(title="NubiferOS CLI Configuration")
    table.add_column("Key", style="cyan")
    table.add_column("Value", style="green")
    table.add_column("Default", style="dim")
    
    for k, default in DEFAULT_CONFIG.items():
        value = config.get(k, default)
        is_default = value == default
        table.add_row(k, str(value), str(default) if not is_default else "")
    
    console.print(table)
    console.print(f"\nConfig file: {CONFIG_FILE}")


@app.command("set")
def set_config(
    key: str = typer.Argument(..., help="Config key to set"),
    value: str = typer.Argument(..., help="Value to set"),
) -> None:
    """Set a configuration value."""
    if key not in DEFAULT_CONFIG:
        typer.echo(f"✗ Unknown config key: {key}", err=True)
        typer.echo(f"  Valid keys: {', '.join(DEFAULT_CONFIG.keys())}", err=True)
        raise typer.Exit(1)
    
    config = _load_config()
    
    # Type conversion based on default type
    default_type = type(DEFAULT_CONFIG[key])
    try:
        if default_type == bool:
            config[key] = value.lower() in ("true", "1", "yes", "on")
        elif default_type == int:
            config[key] = int(value)
        else:
            config[key] = value
    except ValueError:
        typer.echo(f"✗ Invalid value type for {key}", err=True)
        raise typer.Exit(1)
    
    if _save_config(config):
        typer.echo(f"✓ Set {key} = {config[key]}")


@app.command("reset")
def reset(
    key: Optional[str] = typer.Argument(None, help="Specific key to reset (or all if not specified)"),
    yes: bool = typer.Option(False, "-y", "--yes", help="Skip confirmation"),
) -> None:
    """Reset configuration to defaults."""
    if key:
        if key not in DEFAULT_CONFIG:
            typer.echo(f"✗ Unknown config key: {key}", err=True)
            raise typer.Exit(1)
        
        config = _load_config()
        config[key] = DEFAULT_CONFIG[key]
        if _save_config(config):
            typer.echo(f"✓ Reset {key} to default: {DEFAULT_CONFIG[key]}")
    else:
        if not yes:
            confirm = typer.confirm("Reset all configuration to defaults?")
            if not confirm:
                raise typer.Abort()
        
        if _save_config(DEFAULT_CONFIG.copy()):
            typer.echo("✓ Reset all configuration to defaults")
