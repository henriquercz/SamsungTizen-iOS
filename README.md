# SamsungTizen-menubar

A native macOS menu bar remote for Samsung TVs running Tizen. Open apps, switch HDMI inputs, navigate with a swipe pad, set the volume, and keep your TV controls a click away.

This is a fork of [LGwebOS-menubar](https://github.com/gabrielgreco1/LGwebOS-menubar), rewritten to speak Samsung's local protocols instead of LG's. It is a community project, independent of Samsung.

> **Compatibility:** tested on one Samsung TV from 2020 (Tizen 5.5). Other models and Tizen versions are not verified. If you try another TV, say so in your issue or pull request, including the model number and year.

## Tested versions

| TV | Status |
| --- | --- |
| UN58TU7020GXZD, 2020, Tizen 5.5 | Works: discovery, pairing, remote keys, volume. The TV does not list its apps, so the app catalog is used. |

## Quick start with Claude

If you use Claude Code, clone this repository and tell Claude:

> Let's use this project. Set it up for my TV.

The `CLAUDE.md` file in the root tells Claude how to build the app, find your TV, check compatibility, and pair. Claude will ask you for anything it cannot find.

## Requirements

- A Mac running macOS 14 or later.
- Xcode Command Line Tools with Swift 5.9 or later. Install them with `xcode-select --install`.
- A Samsung TV with Tizen (2016 or later; pairing over TLS needs 2018 or later), on the same Wi-Fi or Ethernet network as your Mac.

## Build and run

```sh
bash scripts/build.sh
open "dist/SamsungTizen-menubar.app"
```

The script builds in a temporary directory, removes debug symbols, and creates a locally signed app bundle. It does not connect to a TV. Locally built apps are not notarized, so macOS may ask you to confirm the first time you open it.

By default the app is signed ad hoc, so macOS treats every rebuild as a new app and asks again for Keychain and Local Network access. If you have a signing certificate, pass it to keep those approvals:

```sh
SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" bash scripts/build.sh
```

## Connect your TV

1. Turn on the TV and make sure your Mac is on the same network.
2. Open the app from the menu bar, then open Settings.
3. Choose **Find TVs on your network**, or enter the TV's IPv4 address (it looks like `192.0.2.42`).
4. Choose **Save and connect**. Approve the certificate prompt on your Mac. A request from SamsungTizen-menubar appears on the TV: choose **Allow** with the TV remote.

If macOS asks for Local Network access, allow it. Discovery may not work on guest networks or networks with device isolation. In that case, enter the IP address manually.

The name, model, and Wi-Fi MAC address are read from the TV. The pairing token and the TV certificate fingerprint are stored in your Mac's Keychain. To pair again, use **Forget pairing** in Settings. If you chose Deny on the TV by mistake, remove the Mac from the TV's list under Settings, General, External Device Manager, Device Connection Manager, Device List.

The project ships with no TV address, device name, model, MAC address, or pairing token.

## How it talks to the TV

| What | How |
| --- | --- |
| Remote keys, text input, opening apps | Smart View WebSocket at `wss://TV:8002`, paired with a token the TV issues after you choose Allow |
| Name, model, power state, Wi-Fi MAC | Read-only description at `http://TV:8001/api/v2/` |
| Volume, mute, playing a file from the Mac | The TV's UPnP/DLNA renderer on port 9197 |
| Turning the TV on | Wake-on-LAN to the TV's Wi-Fi MAC address |

## Compatibility and limits

- **Apps:** Tizen 5 and later (2020 on) no longer list installed apps. The app then shows a catalog of common Samsung apps with their known IDs. Right-click an app you do not have to hide it. Older TVs send their own list and icons.
- **What is on screen:** Samsung TVs do not report the open app over the local network. The app shows what you opened from the Mac. Changes made with the TV remote are not seen.
- **Inputs:** there is no input list either. HDMI 1 to 4 and Live TV switch with their own keys; set how many HDMI ports your TV has in Settings. Right-click an input to rename it, for example to PS5. The Source button opens the TV's own menu.
- **Swipe pad:** Tizen menus move by focus, so swipes send arrow keys and a tap sends OK.
- **Volume:** read and set through UPnP. When the sound goes to a soundbar, the level may be unavailable; the volume buttons still work.
- **Screen time:** counts the app or input opened from this Mac while the TV is on and the Mac is awake and connected.
- **Picture settings:** not available. Samsung offers no local API for them.
- **Media casting:** playback depends on the TV's supported codecs. Only the selected file is served, through a temporary URL reachable from the TV and this Mac only. H.264 MP4, MP3, and JPEG are the safest choices. The TV may ask once whether to allow the Mac.
- **AirPlay:** Samsung TVs from 2018 on support AirPlay 2. macOS lets only its own Control Center start screen mirroring, so the app shows where to find it. It does not start mirroring itself.
- **Wake:** requires Power On with Mobile in the TV's network settings.
- **Certificates:** Samsung TVs share one Smart View certificate. The pin detects a change, but it cannot tell two Samsung TVs apart; the pairing token is what authorizes this Mac.

## Privacy and local storage

The app has no analytics, accounts, or cloud services. TV control stays on your local network. Catalog icons are bundled with the app; other icons a TV sends are cached locally.

Preferences, favorites, and hidden apps are stored in macOS preferences. Usage, activity history, and cached icons are stored under `~/Library/Application Support/br.local.TizenRemote/`. Pairing tokens and certificate pins are stored in Keychain, separately for each TV address. None of these runtime files are part of this repository.

## Offline checks

These run without a TV and without access to your saved pairing:

```sh
bash scripts/build.sh
"dist/SamsungTizen-menubar.app/Contents/MacOS/TizenMenubar" --self-check
python3 scripts/privacy-check.py
```

`--self-check` runs isolated tests for the Smart View frames, pairing handshake, app list and TV description parsing, catalog matching, activity tracking, swipe pad, preferences, certificates, usage, resources, and the loopback media server. `privacy-check.py` scans the files that would be published for local paths, device addresses, and saved pairing keys. It is a review aid, not a guarantee for every new file.

## Diagnostics

Diagnostics need an explicit TV address and do not switch inputs or open apps. Reports contain local device information, so keep them private.

```sh
mkdir -p .local
"dist/SamsungTizen-menubar.app/Contents/MacOS/TizenMenubar" \
  --diagnose --host "YOUR_TV_IP" --report .local/diagnostics.json
```

For a TV that is not paired yet, add `--trust-new-tv` to enable the certificate prompt and the Allow request on the TV. Run `--help` for all options.

## Contributing

Bug reports and pull requests are welcome. Use English for code, interface text, documentation, and issues.

When you report a problem, include:

- macOS version
- TV model and year
- Steps to reproduce
- A redacted error message

Keep IP addresses, MAC addresses, serial numbers, pairing tokens, and diagnostic reports out of public issues and pull requests.

## License

MIT. See [LICENSE](LICENSE). Third-party material and brand assets are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
