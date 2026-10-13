# SamsungTizen-menubar: setup guide for Claude

This is a native macOS menu bar app that controls a Samsung TV running Tizen. It is a fork of LGwebOS-menubar. When a user asks you to set it up, follow these steps in order. Ask the user for anything you cannot find yourself. Do not guess an IP address, MAC address, or TV model.

## 1. Check the Mac

- Confirm macOS 14 or later: `sw_vers -productVersion`.
- Confirm Swift 5.9 or later: `swift --version`. If Swift is missing, tell the user to run `xcode-select --install`.

## 2. Build the app

```sh
bash scripts/build.sh
```

The output is `dist/SamsungTizen-menubar.app`. Do not commit the `dist/` folder. If the user has a code signing identity (`security find-identity -v -p codesigning`), offer to build with `SIGN_IDENTITY="<name>"`, so macOS keeps Keychain and Local Network approvals across rebuilds.

## 3. Find the TV

The TV describes itself without pairing. With its IPv4 address:

```sh
curl -s http://TV_IP:8001/api/v2/
```

The answer has the name, model (`modelName`), model year (first two digits of `model`), power state, and Wi-Fi MAC address. If you do not know the address, the app's **Find TVs on your network** searches for it, or the user can read it from their router's device list. Hostnames and IPv6 are not supported.

## 4. Check compatibility

- The app has been tested on one 2020 Samsung TV (Tizen 5.5). Other models and years are unverified.
- TVs from 2020 on do not list installed apps; the app falls back to its catalog. Older TVs send their list.
- If the user's TV is different, explain the compatibility status before continuing. If they try it, report the result and suggest an issue with the model number and year.

## 5. Run the offline checks

```sh
"dist/SamsungTizen-menubar.app/Contents/MacOS/TizenMenubar" --self-check
python3 scripts/privacy-check.py
```

Both should pass before you go further.

## 6. Connect and pair

Open the app: `open "dist/SamsungTizen-menubar.app"`. Then the user does this in the app:

1. Open Settings.
2. Choose **Find TVs on your network**, or enter the IPv4 address.
3. Choose **Save and connect** and approve the certificate prompt.
4. Choose **Allow** on the TV with the TV remote.

You cannot do the last step for them. If macOS asks for Local Network access, the user must allow it.

## Rules while setting up

- Never write the user's IP address, MAC address, serial number, or pairing token into a tracked file. Keep them in the app's settings or in `.local/`, which is ignored by git.
- Do not change the compatibility notes in the README unless the user has tested a new TV and asks you to.
- If something fails, report the exact error and what you ruled out. Do not send pairing requests repeatedly; a TV that was denied must be removed from its Device Connection Manager list before it asks again.
