# Samsung Tizen iOS Improvements & Bugfixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix iPhone screen aspect ratio/letterboxing, enable reliable Wake-on-LAN power on from standby, add a direct sleep timer for automatic TV shutdown, localize the entire app to Brazilian Portuguese (pt-BR), and generate/integrate a modern 2026 Liquid Glass app logo and icon.

**Architecture:** 
- Add native `LaunchScreen.storyboard` and explicit `TARGETED_DEVICE_FAMILY: "1,2"` to remove iOS legacy compatibility letterbox mode.
- Harden Wake-on-LAN in `Discovery.swift` with multi-key MAC extraction (`wifiMac`, `mac`, `wiredMac`), hex sanitization, dual ports (9 and 7), subnet broadcast support, burst transmissions, and auto-reconnect logic in `RemoteStore.swift`.
- Implement an in-app `SleepTimer` inside `RemoteStore.swift` with live countdown state and UI presets (15m, 30m, 45m, 1h, 1h30, 2h) in `RemoteView.swift`.
- Translate all user-facing strings across `RemoteView.swift`, `RemoteStore.swift`, and `ConnectionTrustPrompt.swift` to pt-BR.
- Generate a 1024x1024 Liquid Glass icon via the image-generator subagent, assemble `AppIcon.appiconset`, and wire it through `project.yml`.

**Tech Stack:** Swift 5.9, SwiftUI, UIKit, BSD Sockets (Wake-on-LAN UDP broadcast), XcodeGen, Codemagic CI/CD.

**Spec:** User feedback from initial iPhone testing: letterboxed black bars on top and bottom, inability to turn TV back on once powered down, need for quick sleep timer without deep TV menus, Brazilian Portuguese translation, and a custom 2026 Liquid Glass app icon matching the color palette.

## Global Constraints
- Target iOS 17.0+.
- No third-party package dependencies (standard library and Apple frameworks only: SwiftUI, UIKit, Network/BSD sockets).
- Follow `/ponytail full` principles: concise, minimal code, native platform capabilities first.
- Strict separate Git commits for each task with clear semantic messages.

## Review Focus
1. Wake-on-LAN packet delivery on Wi-Fi subnets when TV ARP entry is expired in router.
2. MAC address variations from Samsung TV `/api/v2/` (`wifiMac`, `mac`, `wiredMac`, uppercase/lowercase, dashes/colons/none).
3. iPhone aspect ratio on notched and Dynamic Island displays without black letterboxing bands.
4. Sleep timer accuracy and state persistence during app backgrounding.
5. Codemagic build reproducibility with asset catalog and LaunchScreen.

---

### Task 1: Fix iPhone Fullscreen / Letterboxing & Display Sizing

**Files:**
- Create: `Sources/SamsungTizen/LaunchScreen.storyboard`
- Modify: `Sources/SamsungTizen/Info.plist`
- Modify: `project.yml`

**Interfaces:**
- Produces: `UILaunchStoryboardName` set to `LaunchScreen`, `TARGETED_DEVICE_FAMILY: "1,2"`.

- [ ] **Step 1: Create `LaunchScreen.storyboard`**
Create a clean, dark OLED launch screen storyboard with `#0A0D12` background color matching the app's ambient background so iOS recognizes native screen dimensions on all iPhone models.

- [ ] **Step 2: Update `Info.plist`**
Reference `LaunchScreen` in `UILaunchStoryboardName` and remove the empty `UILaunchScreen` dictionary.

- [ ] **Step 3: Update `project.yml`**
Explicitly add `TARGETED_DEVICE_FAMILY: "1,2"` to the application target settings so XcodeGen configures universal iPhone & iPad native resolution.

- [ ] **Step 4: Verify project configuration**
Ensure `LaunchScreen.storyboard` is included in sources and `Info.plist` is properly referenced.

- [ ] **Step 5: Commit**
```bash
git add Sources/SamsungTizen/LaunchScreen.storyboard Sources/SamsungTizen/Info.plist project.yml
git commit -m "fix: add LaunchScreen and targeted device family to eliminate iPhone letterboxing"
```

---

### Task 2: Reliable Wake-on-LAN (Ligar a TV) & MAC Address Detection

**Files:**
- Modify: `Sources/SamsungTizen/Discovery.swift:20-65, 120-137`
- Modify: `Sources/SamsungTizen/RemoteStore.swift:368-376`

**Interfaces:**
- Consumes: TV description JSON from `http://<host>:8001/api/v2/`
- Produces: `TVDiscovery.wake(mac: String, host: String)` supporting normalized hex, subnet broadcast, dual ports (9 and 7), and burst sending; `RemoteStore.power()` with automatic reconnect attempt on wake.

- [ ] **Step 1: Harden MAC extraction in `TVInfo.parse`**
Update `TVInfo.parse` to look for `wifiMac`, `mac`, and `wiredMac`, falling back to whatever MAC identifier the TV provides.

- [ ] **Step 2: Sanitize MAC addresses in `TVDiscovery.wake`**
Strip any delimiters (`:`, `-`, `.`), enforce 12 hexadecimal characters, and convert into 6 raw bytes.

- [ ] **Step 3: Multi-target and multi-port UDP Wake-on-LAN broadcast**
Send the 102-byte magic packet to:
1. `host` (unicast)
2. `255.255.255.255` (limited broadcast)
3. Subnet broadcast address calculated from `host` (e.g. `192.168.X.255`)
Send across both port 9 and port 7 with 3 repeat bursts (spaced 30ms) to counteract packet loss on sleeping Wi-Fi radios.

- [ ] **Step 4: Update `RemoteStore.power()`**
When waking the TV (`connected == false`), send wake signal and schedule an automatic connection attempt after 3 seconds so the app immediately hooks onto the TV once it boots.

- [ ] **Step 5: Commit**
```bash
git add Sources/SamsungTizen/Discovery.swift Sources/SamsungTizen/RemoteStore.swift
git commit -m "fix: improve Wake-on-LAN and MAC discovery to reliably power on TV from standby"
```

---

### Task 3: Direct Sleep Timer (Desligamento Automático da TV)

**Files:**
- Modify: `Sources/SamsungTizen/RemoteStore.swift`
- Modify: `Sources/SamsungTizen/RemoteView.swift`

**Interfaces:**
- Produces: `RemoteStore.sleepTimerRemaining: TimeInterval?`, `RemoteStore.startSleepTimer(minutes: Int)`, `RemoteStore.cancelSleepTimer()`.
- UI: Floating sleep timer pill with live countdown and a quick preset sheet/menu (15m, 30m, 45m, 1h, 1h30, 2h, Desativar) accessible from the TV header and remote tab.

- [ ] **Step 1: Implement Sleep Timer logic in `RemoteStore`**
Add `@Published var sleepTimerSecondsRemaining: Int? = nil` with a 1-second interval timer. When countdown reaches 0, invoke `client.key("KEY_POWER")` or `client.key("KEY_POWEROFF")`, disconnect, and notify.

- [ ] **Step 2: Add Sleep Timer quick action and preset modal in `RemoteView`**
Add a sleek clock/timer capsule button in the floating header or TV controls:
- Tapping opens presets: 15 min, 30 min, 45 min, 60 min (1 hora), 90 min (1h30), 120 min (2 horas), or Cancelar.
- When active, show an animated glass pill with remaining time (e.g., `⏱️ Desliga em 29:45`) and 1-tap cancellation.

- [ ] **Step 3: Test and verify timer behavior**
Ensure canceling works, timer decrements correctly, and power-off command fires at 0.

- [ ] **Step 4: Commit**
```bash
git add Sources/SamsungTizen/RemoteStore.swift Sources/SamsungTizen/RemoteView.swift
git commit -m "feat: add direct sleep timer for automatic TV power off"
```

---

### Task 4: Complete Brazilian Portuguese (pt-BR) Localization

**Files:**
- Modify: `Sources/SamsungTizen/RemoteView.swift`
- Modify: `Sources/SamsungTizen/RemoteStore.swift`
- Modify: `Sources/SamsungTizen/ConnectionTrustPrompt.swift`
- Modify: `Sources/SamsungTizen/Info.plist`

**Interfaces:**
- All user-facing strings translated to idiomatic Brazilian Portuguese.

- [ ] **Step 1: Translate navigation tabs and headers**
- TV -> TV
- Remote -> Controle
- Apps -> Apps (ou Aplicativos)
- Cast -> Transmitir
- Activity -> Atividade

- [ ] **Step 2: Translate remote control buttons, D-pad, and status messages**
Translate all tooltips, labels (Power, Volume, Mudo, Canais, Início, Voltar, Guia, Configurações, Teclado, etc.), and connection states ("Conectado", "Conectando...", "Desconectado", "TV ligada", "TV desligada").

- [ ] **Step 3: Translate settings, pairing alerts, and cast options**
Translate "Renomear Entrada", "Esquecer pareamento", "Buscar TV ou IP", "Transmissão de Mídia", and permission prompts.

- [ ] **Step 4: Update `Info.plist` language and permission descriptions**
Set `CFBundleDevelopmentRegion` to `pt-BR` and provide Portuguese descriptions for `NSLocalNetworkUsageDescription` and `NSPhotoLibraryUsageDescription`.

- [ ] **Step 5: Commit**
```bash
git add Sources/SamsungTizen/RemoteView.swift Sources/SamsungTizen/RemoteStore.swift Sources/SamsungTizen/ConnectionTrustPrompt.swift Sources/SamsungTizen/Info.plist
git commit -m "feat: localize entire app interface to Brazilian Portuguese (pt-BR)"
```

---

### Task 5: App Logo & Icon Generation and Integration

**Files:**
- Create: `Sources/SamsungTizen/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Sources/SamsungTizen/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- Modify: `project.yml`
- Modify: `Sources/SamsungTizen/RemoteView.swift`

**Interfaces:**
- Produces: 1024x1024 Liquid Glass icon matching the palette and design system, configured as the primary iOS AppIcon.

- [ ] **Step 1: Invoke image-generator subagent**
Prompt the `image-generator` subagent to generate a stunning, ultra-premium 2026 Liquid Glass Samsung TV Remote app icon:
- Dark OLED graphite/black background (`#0A0D12`).
- Floating translucent frosted glass capsule with subtle cyan/Samsung electric blue glow (`#007AFF` / `#1428A0`).
- Sleek minimalist glowing power/remote glyph with specular rim highlights.
- Modern iOS 2026 aesthetics.

- [ ] **Step 2: Create `Assets.xcassets` and `AppIcon.appiconset`**
Set up the standard iOS asset catalog with `Contents.json` specifying the 1024x1024 universal single-size AppIcon (standard for iOS 17+).

- [ ] **Step 3: Update `project.yml` to compile the Asset Catalog**
Configure `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml` targets settings.

- [ ] **Step 4: Integrate the brand logo into the in-app header**
Display the app logo icon in the top floating header next to the TV status.

- [ ] **Step 5: Commit**
```bash
git add Sources/SamsungTizen/Assets.xcassets project.yml Sources/SamsungTizen/RemoteView.swift
git commit -m "feat: generate and integrate 2026 Liquid Glass app logo and icon"
```

---

### Task 6: Build, Package and Verification via Codemagic

**Files:**
- All modified files
- Output: `SamsungTizen.ipa`

- [ ] **Step 1: Verify code integrity locally**
Ensure syntax, files, and project specifications are clean.

- [ ] **Step 2: Commit and push to GitHub `origin/main`**
Push all task commits to GitHub remote.

- [ ] **Step 3: Trigger Codemagic cloud build**
Run `powershell -File "C:\Users\Administrator\.gemini\antigravity\bin\codemagic.ps1" start 6acfcb87f3e586e974889f87`.

- [ ] **Step 4: Monitor build and download `.ipa`**
Wait for build to complete successfully and download the newly packaged `SamsungTizen.ipa`.
