# Samsung Tizen iOS: Sleep Timer Background Audio, Keychain Security, Smart Inputs, Favorites & Touch Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a completely silent, reliable background sleep timer on iOS (without triggering TV menus), migrate TV pairing credentials to the secure iOS Keychain, introduce smart HDMI input brand recognition (including Fire TV, PlayStation, Xbox, Apple TV), add favorite/pinned apps with quick-access sorting, and enlarge touch metrics (220 pt D-pad) to fill iPhone screens naturally.

**Architecture:**
- **Background Keep-Alive**: `BackgroundAudioTimer` manages an ultra-low-power silent `AVAudioSession` (`.playback`, `.mixWithOthers`) during the sleep timer countdown, preventing iOS suspension when the phone is locked. On deadline expiry, it sends `KEY_POWER` via network and deactivates immediately. Removes the noisy `KEY_SLEEP` macro.
- **Keychain Security**: `PairingKey` uses Apple's `Security.framework` (`kSecClassGenericPassword`) for hardware-backed token storage in the Secure Enclave, eliminating unencrypted file storage and surviving cache purges.
- **Smart Brand Recognition**: `SmartDevice` parses HDMI input labels (e.g. "Fire TV", "PS5", "Xbox", "Apple TV", "Switch") and renders official iconography and brand colors.
- **Favorites & Catalog Sorting**: `RemoteStore` adds `favoriteAppIDs: Set<String>` persisted in `UserDefaults`, prioritizing user favorites in the Apps tab.
- **Touch Ergonomics**: `RemoteMetrics` defines generous 220 pt D-pad and 48–56 pt button hitboxes adhering to Apple Human Interface Guidelines.

**Tech Stack:** Swift 5.9+, SwiftUI, AVFoundation (`AVAudioSession`), Security (`SecItem`), Foundation.

**Spec:** Brainstorming alignment from 2026-10-14 conversation.

## Global Constraints
- Target iOS 17.0+
- Pure native Swift / SwiftUI, 0 third-party package dependencies
- 100% Brazilian Portuguese (`pt-BR`) copy
- Pass privacy check: `python scripts/privacy-check.py` (0 errors, no literal RFC 1918 IPs in committed files)
- Keep battery consumption strictly under 1% per hour of timer

## Review Focus
1. **Background Audio Session Cleanup**: Ensure `AVAudioSession.setActive(false)` is always called on timer cancellation, zero-out, or error, avoiding lingering background assertions.
2. **Keychain Migration**: Gracefully read legacy file tokens if Keychain is initially empty, then save to Keychain so existing paired users are never forced to re-pair.
3. **No Native TV Menu on Sleep**: Ensure `KEY_SLEEP` is never sent, guaranteeing zero on-screen popups on the TV.
4. **Input Brand Matching**: Ensure case-insensitive, fuzzy matching for inputs ("Fire TV Stick", "PlayStation 5", "Nintendo Switch") with graceful fallback to standard cable connector icon.
5. **D-pad Hitbox Integrity**: Enlarged 220 pt D-pad must maintain accurate cardinal direction angles and prevent edge clipping.

---

### Task 1: iOS Keychain Security for Pairing Token (`PairingKey`)

**Files:**
- Create: `Sources/SamsungTizen/Keychain.swift`
- Modify: `Sources/SamsungTizen/Tizen.swift`
- Modify: `Sources/SamsungTizen/RemoteStore.swift`
- Test: `Sources/SamsungTizen/FeatureChecks.swift`

**Steps:**
- [ ] 1.1 Create `Sources/SamsungTizen/Keychain.swift` implementing `PairingKey`:
  - `static func read(_ host: String) -> String?` using `SecItemCopyMatching` with `kSecClassGenericPassword` and service `"br.local.SamsungRemote"`.
  - `static func save(_ key: String, host: String) throws` updating existing item or adding with `kSecAttrAccessibleAfterFirstUnlock`.
  - `static func delete(_ host: String)` using `SecItemDelete`.
- [ ] 1.2 In `Sources/SamsungTizen/Tizen.swift` / `RemoteStore.swift`:
  - Update `loadToken()`: Check `PairingKey.read(host)` first; if nil, check legacy `pairing.json` on disk; if found in legacy file, save to Keychain and remove file.
  - Update `saveToken()`: Call `try? PairingKey.save(token, host: host)`.
  - Update `forgetPairing()`: Call `PairingKey.delete(pairingHost)`.
- [ ] 1.3 Add test `testKeychainPairingRoundtrip()` in `FeatureChecks.swift`.
- [ ] 1.4 Run privacy check and commit: `feat(security): store TV pairing tokens in iOS Keychain with hardware encryption`.

---

### Task 2: Silent Background Audio Timer (Sleep Timer Without TV Menus)

**Files:**
- Create: `Sources/SamsungTizen/BackgroundAudioTimer.swift`
- Modify: `Sources/SamsungTizen/Info.plist`
- Modify: `Sources/SamsungTizen/RemoteStore.swift`
- Test: `Sources/SamsungTizen/FeatureChecks.swift`

**Steps:**
- [ ] 2.1 Update `Sources/SamsungTizen/Info.plist`:
  - Add `UIBackgroundModes` array containing string `"audio"`.
- [ ] 2.2 Create `Sources/SamsungTizen/BackgroundAudioTimer.swift`:
  - Main actor singleton `BackgroundAudioTimer.shared`.
  - `func start()`: Configures `AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])`, activates session, and begins playing a silent audio loop or silent audio buffer generator with volume 0.0.
  - `func stop()`: Stops playback and deactivates session with `try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])`.
- [ ] 2.3 In `Sources/SamsungTizen/RemoteStore.swift`:
  - In `startSleepTimer(minutes:)`:
    - Remove `perform { client in try await client.key("KEY_SLEEP") }`.
    - Call `BackgroundAudioTimer.shared.start()`.
    - When countdown finishes (`remaining <= 0`):
      - Call `self.press("KEY_POWER")`.
      - Call `BackgroundAudioTimer.shared.stop()`.
      - Call `self.disconnect()`.
      - Set `self.notice = "TV desligada pelo timer."`.
  - In `cancelSleepTimer()`:
    - Call `BackgroundAudioTimer.shared.stop()`.
- [ ] 2.4 Add check `testBackgroundAudioTimerLifecycle()` in `FeatureChecks.swift`.
- [ ] 2.5 Run privacy check and commit: `feat(timer): silent background audio keep-alive for sleep timer without TV menus`.

---

### Task 3: Smart HDMI Input Recognition (Fire TV, PlayStation, Xbox, Apple TV, Switch)

**Files:**
- Modify: `Sources/SamsungTizen/BrandTheme.swift`
- Modify: `Sources/SamsungTizen/RemoteView.swift`
- Test: `Sources/SamsungTizen/FeatureChecks.swift`

**Steps:**
- [ ] 3.1 In `Sources/SamsungTizen/BrandTheme.swift`:
  - Create enum `ConnectedDeviceType`: `.playstation`, `.xbox`, `.nintendoSwitch`, `.appleTV`, `.fireTV`, `.chromecast`, `.generic`.
  - Add parser `static func detect(label: String) -> ConnectedDeviceType`:
    - Case-insensitive matching for:
      - Fire TV: `"fire"`, `"aft"`, `"amazon"` -> `.fireTV` (Orange `#FF9900` accent, `"flame.fill"` or Fire icon).
      - PlayStation: `"playstation"`, `"ps4"`, `"ps5"` -> `.playstation` (Blue `#003791`, `"gamecontroller.fill"`).
      - Xbox: `"xbox"` -> `.xbox` (Green `#107C10`, `"gamecontroller.fill"`).
      - Nintendo: `"switch"`, `"nintendo"` -> `.nintendoSwitch` (Red `#E60012`, `"gamecontroller.fill"`).
      - Apple TV: `"apple"`, `"appletv"` -> `.appleTV` (Silver/White `#A2AAAD`, `"appletv.fill"`).
      - Chromecast: `"chromecast"`, `"google"` -> `.chromecast` (Cyan `#4285F4`, `"tv.and.mediabox"`).
      - Default: `.generic` (Muted `#8E8E93`, `"cable.connector"`).
- [ ] 3.2 In `Sources/SamsungTizen/RemoteView.swift`:
  - Update `inputsPanel` rendering to display the smart badge, device brand color, and custom symbol for each recognized input.
- [ ] 3.3 Add unit test `testSmartDeviceTypeDetection()` in `FeatureChecks.swift`.
- [ ] 3.4 Run privacy check and commit: `feat(inputs): smart HDMI device recognition for Fire TV, PlayStation, Xbox, and consoles`.

---

### Task 4: Favorite & Pinned Apps with Smart Ordering

**Files:**
- Modify: `Sources/SamsungTizen/RemoteStore.swift`
- Modify: `Sources/SamsungTizen/RemoteView.swift`
- Test: `Sources/SamsungTizen/FeatureChecks.swift`

**Steps:**
- [ ] 4.1 In `Sources/SamsungTizen/RemoteStore.swift`:
  - Add `@Published var favoriteAppIDs: Set<String>` initialized from `UserDefaults.standard.stringArray(forKey: "tv.favorites")` (defaults to `["111299001912", "3201907018807", "3201910019365"]` for YouTube, Netflix, Prime Video).
  - Add `func toggleFavorite(_ appID: String)`: Inserts/removes and writes to `UserDefaults`.
  - Add `func isFavorite(_ appID: String) -> Bool`.
  - Add computed property `var sortedApps: [TVApp]`: Places favorited apps first, followed by alphabetical order.
- [ ] 4.2 In `Sources/SamsungTizen/RemoteView.swift`:
  - In `appsPanel`:
    - Add a "Favoritos" highlighted quick-strip at the top of the grid.
    - Add a context menu or star badge on app tiles allowing instant toggling of favorite status.
- [ ] 4.3 Add unit test `testFavoritesPersistenceAndSorting()` in `FeatureChecks.swift`.
- [ ] 4.4 Run privacy check and commit: `feat(apps): add favorite apps pinning and quick-access top row`.

---

### Task 5: Mobile Touch Ergonomics & 220 pt D-Pad Scaling (`RemoteMetrics`)

**Files:**
- Create: `Sources/SamsungTizen/RemoteMetrics.swift`
- Modify: `Sources/SamsungTizen/RemoteView.swift`
- Test: `Sources/SamsungTizen/FeatureChecks.swift`

**Steps:**
- [ ] 5.1 Create `Sources/SamsungTizen/RemoteMetrics.swift`:
  - `struct RemoteMetrics`:
    - `static let mobile = RemoteMetrics(padDiameter: 220, centerButtonDiameter: 76, sideButtonWidth: 56, sideButtonHeight: 52, rockerWidth: 54, rockerHeight: 140, navButtonHeight: 46)`
- [ ] 5.2 In `Sources/SamsungTizen/RemoteView.swift`:
  - Update `directionalPad` to use `RemoteMetrics.mobile.padDiameter` (220 pt instead of 170 pt).
  - Update center OK button to 76 pt for effortless thumb engagement.
  - Ensure rocker and navigation buttons use the expanded hitboxes.
- [ ] 5.3 Test layout across standard iPhone viewports.
- [ ] 5.4 Run privacy check and commit: `feat(ui): scale D-pad to 220pt touch metrics for natural mobile ergonomics`.

---

### Task 6: Comprehensive Verification, Build & Codemagic Release

**Files:**
- Modify: `Sources/SamsungTizen/FeatureChecks.swift`

**Steps:**
- [ ] 6.1 Run all self-tests via `FeatureChecks.swift`.
- [ ] 6.2 Run `python scripts/privacy-check.py` to ensure complete compliance.
- [ ] 6.3 Git commit and push to `origin main`.
- [ ] 6.4 Trigger Codemagic build: `powershell -File "C:\Users\Administrator\.gemini\antigravity\bin\codemagic.ps1" start 6acfcb87f3e586e974889f87 ios-sideload-build`.
- [ ] 6.5 Monitor until `FINISHED` and download `SamsungTizen.ipa`.
