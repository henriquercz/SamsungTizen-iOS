#!/usr/bin/env python3
"""Inject necessary keys into the built app bundle Info.plist to guarantee native fullscreen."""
import glob
import os
import plistlib
import sys

def main():
    payload_apps = glob.glob("build/Payload/*.app")
    if not payload_apps:
        print("Error: No .app found in build/Payload/")
        sys.exit(1)

    app_dir = payload_apps[0]
    plist_path = os.path.join(app_dir, "Info.plist")
    print(f"Injecting keys into: {plist_path}")

    current = {}
    if os.path.exists(plist_path):
        try:
            with open(plist_path, "rb") as f:
                current = plistlib.load(f)
        except Exception as e:
            print(f"Warning: Failed to parse existing Info.plist: {e}")

    source_plist = "Sources/SamsungTizen/Info.plist"
    if os.path.exists(source_plist):
        try:
            with open(source_plist, "rb") as f:
                source = plistlib.load(f)
                current.update(source)
        except Exception as e:
            print(f"Warning: Failed to load source Info.plist: {e}")

    # Ensure required fullscreen, identity, and branding keys are explicitly present
    current["CFBundleIdentifier"] = "br.local.SamsungTizen"
    current["CFBundleExecutable"] = "Samsung Remote"
    current["CFBundleName"] = "Samsung Remote"
    current["CFBundleDisplayName"] = "Controle Samsung"
    current["CFBundleDevelopmentRegion"] = "pt-BR"
    current["UILaunchStoryboardName"] = "LaunchScreen"
    current["UILaunchScreen"] = {}

    with open(plist_path, "wb") as f:
        plistlib.dump(current, f)

    print("Info.plist successfully updated. Keys present:")
    for k, v in sorted(current.items()):
        print(f"  {k}: {v}")

if __name__ == "__main__":
    main()
