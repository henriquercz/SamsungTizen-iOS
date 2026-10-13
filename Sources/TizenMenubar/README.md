# Source notes

This folder holds the Swift code for the menu bar app. It targets **Samsung Tizen TVs**. Testing so far covers one 2020 Samsung TV (Tizen 5.5), as described in the repository README.

- `Tizen.swift`: the Smart View WebSocket on port 8002, pairing token handshake, keys, text, app list and launch.
- `Discovery.swift`: SSDP discovery, the read-only description on port 8001, and Wake-on-LAN.
- `MediaBridge.swift`: the UPnP renderer on port 9197 for volume and file casting, and the single-file media server.
- `TVActivity.swift`: what this Mac opened, since Samsung TVs do not report the foreground app.
- `app-catalog.json`: bundled icons matched by app name, plus known Samsung app IDs for TVs that no longer list their apps.

Other models and Tizen versions may answer differently. Please say which TV model and year you tested when you open a pull request that changes how the app talks to the TV.
