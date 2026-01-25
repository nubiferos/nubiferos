#!/usr/bin/env python3
"""
NubiferOS GNOME Virtual Desktop Integration
Automatically switches GNOME virtual desktops when switching workspaces
"""

import os
import sys
import json
import subprocess
from pathlib import Path

class GnomeDesktopIntegration:
    """Integrates NubiferOS workspaces with GNOME virtual desktops"""
    
    def __init__(self):
        self.config_dir = Path.home() / '.config' / 'nubifer'
        self.workspace_dir = self.config_dir / 'workspaces'
        
    def get_num_workspaces(self):
        """Get number of GNOME workspaces"""
        try:
            result = subprocess.run(
                ['gsettings', 'get', 'org.gnome.desktop.wm.preferences', 'num-workspaces'],
                capture_output=True,
                text=True,
                check=True
            )
            return int(result.stdout.strip())
        except:
            return 4  # Default
    
    def set_num_workspaces(self, num):
        """Set number of GNOME workspaces"""
        try:
            subprocess.run(
                ['gsettings', 'set', 'org.gnome.desktop.wm.preferences', 'num-workspaces', str(num)],
                check=True
            )
            return True
        except:
            return False
    
    def get_current_desktop(self):
        """Get current GNOME virtual desktop number (0-indexed)"""
        try:
            result = subprocess.run(
                ['wmctrl', '-d'],
                capture_output=True,
                text=True,
                check=True
            )
            for line in result.stdout.split('\n'):
                if '*' in line:  # Current desktop marked with *
                    return int(line.split()[0])
            return 0
        except:
            # Fallback: try xdotool
            try:
                result = subprocess.run(
                    ['xdotool', 'get_desktop'],
                    capture_output=True,
                    text=True,
                    check=True
                )
                return int(result.stdout.strip())
            except:
                return 0
    
    def switch_to_desktop(self, desktop_num):
        """Switch to GNOME virtual desktop"""
        try:
            # Try wmctrl first (works on X11 and Wayland with some setups)
            subprocess.run(
                ['wmctrl', '-s', str(desktop_num)],
                check=True,
                stderr=subprocess.DEVNULL
            )
            return True
        except:
            pass
        
        try:
            # Try xdotool (X11 only)
            subprocess.run(
                ['xdotool', 'set_desktop', str(desktop_num)],
                check=True,
                stderr=subprocess.DEVNULL
            )
            return True
        except:
            pass
        
        try:
            # Try gdbus (Wayland-compatible)
            subprocess.run(
                ['gdbus', 'call', '--session',
                 '--dest', 'org.gnome.Shell',
                 '--object-path', '/org/gnome/Shell',
                 '--method', 'org.gnome.Shell.Eval',
                 f'global.workspace_manager.get_workspace_by_index({desktop_num}).activate(global.get_current_time())'],
                check=True,
                stderr=subprocess.DEVNULL
            )
            return True
        except:
            pass
        
        print(f"⚠️  Could not switch to desktop {desktop_num}", file=sys.stderr)
        print(f"   Install wmctrl or xdotool for automatic desktop switching", file=sys.stderr)
        return False
    
    def assign_workspace_to_desktop(self, workspace_id, desktop_num=None):
        """Assign a workspace to a specific GNOME virtual desktop"""
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        
        if not workspace_file.exists():
            print(f"✗ Workspace not found: {workspace_id}", file=sys.stderr)
            return False
        
        # Load workspace config
        with open(workspace_file, 'r') as f:
            workspace = json.load(f)
        
        # Auto-assign if not specified
        if desktop_num is None:
            # Find next available desktop
            used_desktops = set()
            for ws_file in self.workspace_dir.glob('*.json'):
                with open(ws_file, 'r') as f:
                    ws = json.load(f)
                    if 'virtual_desktop' in ws:
                        used_desktops.add(ws['virtual_desktop'])
            
            # Find first unused desktop (0-indexed)
            desktop_num = 0
            while desktop_num in used_desktops:
                desktop_num += 1
        
        # Ensure GNOME has enough desktops
        current_desktops = self.get_num_workspaces()
        if desktop_num >= current_desktops:
            self.set_num_workspaces(desktop_num + 1)
        
        # Update workspace config
        workspace['virtual_desktop'] = desktop_num
        
        with open(workspace_file, 'w') as f:
            json.dump(workspace, f, indent=2)
        
        print(f"✓ Workspace '{workspace['name']}' assigned to virtual desktop {desktop_num + 1}")
        return True
    
    def switch_workspace_with_desktop(self, workspace_id):
        """Switch workspace and automatically switch GNOME virtual desktop"""
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        
        if not workspace_file.exists():
            print(f"✗ Workspace not found: {workspace_id}", file=sys.stderr)
            return False
        
        # Load workspace config
        with open(workspace_file, 'r') as f:
            workspace = json.load(f)
        
        # Get assigned virtual desktop
        desktop_num = workspace.get('virtual_desktop')
        
        if desktop_num is None:
            # Auto-assign if not set
            self.assign_workspace_to_desktop(workspace_id)
            with open(workspace_file, 'r') as f:
                workspace = json.load(f)
            desktop_num = workspace.get('virtual_desktop', 0)
        
        # Switch to virtual desktop
        print(f"Switching to virtual desktop {desktop_num + 1}...")
        success = self.switch_to_desktop(desktop_num)
        
        if success:
            print(f"✓ Switched to virtual desktop {desktop_num + 1}")
            
            # Set wallpaper for this desktop (if supported)
            self.set_desktop_wallpaper(workspace)
        
        return success
    
    def set_desktop_wallpaper(self, workspace):
        """Set wallpaper based on workspace provider"""
        provider = workspace.get('provider', 'default')
        
        # Wallpaper paths
        wallpaper_map = {
            'aws': '/usr/share/backgrounds/nubiferos/aws.png',
            'azure': '/usr/share/backgrounds/nubiferos/azure.png',
            'gcp': '/usr/share/backgrounds/nubiferos/gcp.png',
            'oracle': '/usr/share/backgrounds/nubiferos/oracle.png',
            'multi': '/usr/share/backgrounds/nubiferos/default.png',
        }
        
        wallpaper = wallpaper_map.get(provider, '/usr/share/backgrounds/nubiferos/default.png')
        
        # Check if wallpaper exists
        if not os.path.exists(wallpaper):
            # Try SVG version
            wallpaper = wallpaper.replace('.png', '.svg')
            if not os.path.exists(wallpaper):
                return
        
        try:
            # Set wallpaper
            subprocess.run(
                ['gsettings', 'set', 'org.gnome.desktop.background', 'picture-uri', f'file://{wallpaper}'],
                check=True,
                stderr=subprocess.DEVNULL
            )
            subprocess.run(
                ['gsettings', 'set', 'org.gnome.desktop.background', 'picture-uri-dark', f'file://{wallpaper}'],
                check=True,
                stderr=subprocess.DEVNULL
            )
            print(f"✓ Wallpaper set to {provider} theme")
        except:
            pass
    
    def list_desktop_assignments(self):
        """List all workspace-to-desktop assignments"""
        print("\nWorkspace → Virtual Desktop Assignments:")
        print("="*60)
        
        assignments = []
        for ws_file in sorted(self.workspace_dir.glob('*.json')):
            with open(ws_file, 'r') as f:
                ws = json.load(f)
                desktop_num = ws.get('virtual_desktop')
                if desktop_num is not None:
                    assignments.append((desktop_num, ws))
        
        # Sort by desktop number
        assignments.sort(key=lambda x: x[0])
        
        for desktop_num, ws in assignments:
            theme = ws.get('theme', {})
            icon = theme.get('icon', '☁️')
            mode_icon = '🔒' if ws.get('read_only', False) else '🔓'
            
            print(f"Desktop {desktop_num + 1}: {icon} {ws['name']} {mode_icon}")
            print(f"           Provider: {theme.get('name', 'Unknown')} | Account: {ws['account_name']}")
        
        if not assignments:
            print("No workspaces assigned to virtual desktops yet")
            print("Run: nubifer-workspace switch <workspace-id> to auto-assign")
    
    def ensure_enough_desktops(self):
        """Ensure GNOME has enough virtual desktops for all workspaces"""
        # Count workspaces
        num_workspaces = len(list(self.workspace_dir.glob('*.json')))
        
        if num_workspaces == 0:
            return
        
        # Get current number of GNOME desktops
        current_desktops = self.get_num_workspaces()
        
        # Need at least as many desktops as workspaces
        needed_desktops = max(num_workspaces, 4)  # Minimum 4
        
        if current_desktops < needed_desktops:
            print(f"Increasing GNOME virtual desktops from {current_desktops} to {needed_desktops}...")
            if self.set_num_workspaces(needed_desktops):
                print(f"✓ GNOME now has {needed_desktops} virtual desktops")
            else:
                print(f"⚠️  Could not increase virtual desktops", file=sys.stderr)


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="GNOME Virtual Desktop Integration for NubiferOS")
    subparsers = parser.add_subparsers(dest="command", help="Commands")
    
    # Switch command
    switch_parser = subparsers.add_parser("switch", help="Switch workspace and virtual desktop")
    switch_parser.add_argument("workspace_id", help="Workspace ID")
    
    # Assign command
    assign_parser = subparsers.add_parser("assign", help="Assign workspace to virtual desktop")
    assign_parser.add_argument("workspace_id", help="Workspace ID")
    assign_parser.add_argument("--desktop", type=int, help="Desktop number (1-indexed)")
    
    # List command
    list_parser = subparsers.add_parser("list", help="List desktop assignments")
    
    # Setup command
    setup_parser = subparsers.add_parser("setup", help="Setup GNOME for workspaces")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    integration = GnomeDesktopIntegration()
    
    if args.command == "switch":
        integration.switch_workspace_with_desktop(args.workspace_id)
    
    elif args.command == "assign":
        desktop_num = args.desktop - 1 if args.desktop else None  # Convert to 0-indexed
        integration.assign_workspace_to_desktop(args.workspace_id, desktop_num)
    
    elif args.command == "list":
        integration.list_desktop_assignments()
    
    elif args.command == "setup":
        integration.ensure_enough_desktops()
        print("\n✓ GNOME virtual desktop setup complete")
        print("\nNext steps:")
        print("  1. Create workspaces: nubifer-workspace create ...")
        print("  2. Switch workspaces: nubifer-workspace switch <id>")
        print("  3. Virtual desktops will switch automatically!")


if __name__ == "__main__":
    main()
