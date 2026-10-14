import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let mutedInk = Color.white.opacity(0.55)

private enum RemoteTab: String, CaseIterable, Identifiable {
    case home = "TV", remote = "Remote", apps = "Apps", media = "Cast", usage = "Activity"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: return "tv"
        case .remote: return "dpad"
        case .apps: return "square.grid.2x2"
        case .media: return "airplay.video"
        case .usage: return "chart.bar.xaxis"
        }
    }
}

private enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func press() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

private struct GlassButton: ButtonStyle {
    var selected = false
    var accent: Color = BrandTheme.samsungBlue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? accent : Color.white.opacity(0.88))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? accent.opacity(0.22) : Color.white.opacity(configuration.isPressed ? 0.14 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? accent.opacity(0.5) : Color.white.opacity(0.09), lineWidth: 0.7)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct AppMark: View {
    let app: TVApp
    var size: CGFloat = 38
    var body: some View {
        Group {
            if let url = AppIcons.url(for: app),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().interpolation(.high).scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.09))
                    Text(String(app.title.prefix(1)).uppercased())
                        .font(.system(size: size * 0.44, weight: .semibold))
                        .foregroundStyle(mutedInk)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct BrandImage: View {
    let name: String
    var width: CGFloat = 28
    var height: CGFloat = 28
    var body: some View {
        Group {
            if let url = AppResources.bundle.url(forResource: name, withExtension: "png", subdirectory: "AppAssets"),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().interpolation(.high).scaledToFit()
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

struct RemoteView: View {
    @ObservedObject var store: RemoteStore
    @State private var tab: RemoteTab = .home
    @State private var settings = false
    @State private var search = ""
    @State private var text = ""
    @State private var draftHost = ""
    @State private var draftName = ""
    @State private var draftMAC = ""
    @State private var usageDays = 1
    @State private var showEvents = false
    @State private var swipeTranslation = CGSize.zero
    @State private var showFilePicker = false
    @State private var renamingInput: TVInput?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var showForgetConfirm = false

    private var currentApp: TVApp? { store.currentAppID.flatMap { id in store.apps.first { $0.id == id } } }
    private var theme: BrandTheme {
        BrandTheme.forApp(store.displayForegroundID, title: store.currentInput?.label ?? store.currentApp, icon: currentApp.flatMap(AppIcons.url))
    }
    private var accent: Color { theme.color }
    private var activeTitle: String { isPlayStation ? "PlayStation 5" : store.currentApp }

    var body: some View {
        ZStack {
            // Ambient Liquid OLED background
            Color(red: 0.04, green: 0.05, blue: 0.07).ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(store.connected ? 0.20 : 0.06), .clear],
                center: .top,
                startRadius: 40,
                endRadius: 450
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // Floating Liquid Glass Navbar (iOS 2026 Style)
                floatingHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // Main Content View
                ScrollView {
                    VStack(spacing: 14) {
                        if settings {
                            settingsPanel
                        } else {
                            if !store.connected { connectionPanel }
                            tabContent
                        }
                        feedback
                        Color.clear.frame(height: 85) // Space for floating bottom dock
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
            }

            // Floating Liquid Glass Tab Bar (iOS 2026 Bottom Dock)
            VStack {
                Spacer()
                floatingTabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
        .tint(accent)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.movie, .audio, .image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                store.setMediaFile(url)
            }
        }
        .alert("Rename Input", isPresented: $showRenameAlert) {
            TextField("Input Name (e.g. PS5)", text: $renameText)
            Button("Save") {
                if let input = renamingInput {
                    store.renameInput(input, to: renameText)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a friendly name for this TV input port.")
        }
        .confirmationDialog("Forget TV Pairing?", isPresented: $showForgetConfirm, titleVisibility: .visible) {
            Button("Forget pairing", role: .destructive) {
                store.forgetPairing()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The saved token and certificate for this TV will be removed from your device.")
        }
    }

    // MARK: - Floating Liquid Glass Header (Top Navbar)
    private var floatingHeader: some View {
        HStack(spacing: 12) {
            // Brand & Name
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(store.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Circle()
                        .fill(store.connected ? Color.green : store.connecting ? Color.orange : Color.gray.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .shadow(color: store.connected ? Color.green.opacity(0.8) : .clear, radius: 4)
                }
                HStack(spacing: 6) {
                    BrandImage(name: "samsung", width: 44, height: 7).opacity(0.7)
                    Text(store.system.isEmpty ? "Tizen OS" : store.system)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(mutedInk)
                }
            }

            Spacer()

            // Power button with liquid glow
            Button {
                Haptic.heavy()
                store.power()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(store.connected ? .white : mutedInk)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(store.connected ? Color.red.opacity(0.25) : Color.white.opacity(0.08))
                    )
                    .overlay(Circle().strokeBorder(store.connected ? Color.red.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.8))
            }
            .buttonStyle(.plain)

            // Settings gear
            Button {
                Haptic.tap()
                if !settings {
                    draftHost = store.host
                    draftName = store.name
                    draftMAC = store.mac
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    settings.toggle()
                }
            } label: {
                Image(systemName: settings ? "xmark" : "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(settings ? accent : mutedInk)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 7)
    }

    // MARK: - Floating Liquid Glass Tab Bar (Bottom Dock)
    private var floatingTabBar: some View {
        HStack(spacing: 8) {
            ForEach(RemoteTab.allCases) { item in
                let isSelected = tab == item && !settings
                Button {
                    Haptic.tap()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        tab = item
                        settings = false
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        Text(item.rawValue)
                            .font(.system(size: 9, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundStyle(isSelected ? accent : mutedInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Group {
                            if isSelected {
                                Capsule()
                                    .fill(accent.opacity(0.20))
                                    .overlay(Capsule().strokeBorder(accent.opacity(0.4), lineWidth: 0.7))
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.32), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 9)
    }

    // MARK: - Tab Views
    @ViewBuilder private var tabContent: some View {
        switch tab {
        case .home: homePanel
        case .remote: remotePanel
        case .apps: appsPanel
        case .media: mediaPanel
        case .usage: usagePanel
        }
    }

    // MARK: - Home Panel
    private var homePanel: some View {
        VStack(spacing: 14) {
            nowPlayingCard
            audioCard

            if !store.pinnedApps.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Favorites", systemImage: "star.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(accent)
                            Spacer()
                            Button {
                                Haptic.tap()
                                tab = .apps
                            } label: {
                                Text("See all").font(.system(size: 11, weight: .medium)).foregroundStyle(mutedInk)
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                            ForEach(store.pinnedApps) { app in
                                Button {
                                    Haptic.press()
                                    store.launch(app)
                                } label: {
                                    VStack(spacing: 6) {
                                        AppMark(app: app, size: 44)
                                        Text(app.title)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.85))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .disabled(!store.connected)
                            }
                        }
                    }
                }
            }

            inputsPanel
        }
    }

    private var isPlayStation: Bool {
        store.currentInput?.label.localizedCaseInsensitiveContains("PS5") == true ||
        store.currentInput?.label.localizedCaseInsensitiveContains("PlayStation") == true
    }

    private var nowPlayingCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                ZStack {
                    Ellipse()
                        .fill(accent.opacity(store.connected ? 0.35 : 0.08))
                        .frame(width: 240, height: 110)
                        .blur(radius: 36)

                    BrandImage(name: "tv-hero", width: 280, height: 155)

                    VStack(spacing: 8) {
                        if isPlayStation { BrandImage(name: "playstation", width: 44, height: 44) }
                        else if let app = currentApp { AppMark(app: app, size: 44) }
                        else if store.currentInput?.label.localizedCaseInsensitiveContains("Chromecast") == true { BrandImage(name: "googlecast", width: 36, height: 36) }
                        else { BrandImage(name: "samsung", width: 100, height: 16) }

                        if store.connected {
                            Text(activeTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    .shadow(color: accent.opacity(0.6), radius: 14)
                }
                .frame(height: 160)

                HStack {
                    Circle().fill(store.connected ? accent : mutedInk).frame(width: 6, height: 6)
                    Text(store.connected ? (store.currentAppID != nil || store.currentInput != nil ? "Active on your TV" : "Connected") : "Disconnected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(mutedInk)
                    Spacer()
                    if let input = store.currentInput, input.label != defaultLabel(input) {
                        Text(defaultLabel(input))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
                Text(theme.tagline)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Audio Card
    private var audioCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(mutedInk)
                    Text("TV Volume").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if store.hasVolume {
                        Text("\(Int(store.volume))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                    }
                }
                HStack(spacing: 12) {
                    Button {
                        Haptic.press()
                        store.toggleMute()
                    } label: {
                        Image(systemName: store.muted ? "speaker.slash.fill" : "speaker.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(store.muted ? .red : mutedInk)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.connected)

                    Slider(
                        value: Binding(get: { store.volume }, set: store.changeVolume),
                        in: 0...100
                    )
                    .tint(accent)
                    .disabled(!store.connected || !store.hasVolume)

                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 13)).foregroundStyle(mutedInk)
                }
                HStack {
                    Text(store.muted ? "Muted" : store.hasVolume || !store.connected ? "TV speakers" : "Volume buttons work via remote.")
                        .font(.system(size: 10))
                        .foregroundStyle(mutedInk)
                    Spacer()
                    Button {
                        Haptic.press()
                        store.volumeStep(false)
                    } label: {
                        Image(systemName: "minus").frame(width: 34, height: 26)
                    }
                    .buttonStyle(GlassButton(accent: accent))

                    Button {
                        Haptic.press()
                        store.volumeStep(true)
                    } label: {
                        Image(systemName: "plus").frame(width: 34, height: 26)
                    }
                    .buttonStyle(GlassButton(accent: accent))
                }
                .disabled(!store.connected)
            }
        }
    }

    // MARK: - Remote Panel (Full D-Pad and Controls)
    private var remotePanel: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(spacing: 18) {
                    HStack {
                        Text(store.currentApp.isEmpty ? "Samsung Remote" : store.currentApp)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        Circle().fill(store.connected ? Color.green : Color.orange).frame(width: 6, height: 6)
                        Text(store.connected ? "Ready" : "Disconnected").font(.system(size: 10)).foregroundStyle(mutedInk)
                    }

                    // D-Pad and Core Action cluster
                    HStack(spacing: 16) {
                        VStack(spacing: 16) {
                            remoteIconButton("house.fill", "KEY_HOME")
                            remoteIconButton("arrow.uturn.backward", "KEY_RETURN")
                        }

                        // Circular D-Pad
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))

                            VStack {
                                dpadDirection("chevron.up", "KEY_UP")
                                Spacer()
                                dpadDirection("chevron.down", "KEY_DOWN")
                            }
                            .padding(8)

                            HStack {
                                dpadDirection("chevron.left", "KEY_LEFT")
                                Spacer()
                                dpadDirection("chevron.right", "KEY_RIGHT")
                            }
                            .padding(8)

                            // Center OK Button
                            Button {
                                Haptic.press()
                                store.press("KEY_ENTER")
                            } label: {
                                Text("OK")
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 54, height: 54)
                                    .background(Circle().fill(accent.opacity(0.24)))
                                    .overlay(Circle().strokeBorder(accent.opacity(0.6), lineWidth: 1))
                                    .foregroundStyle(accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: 156, height: 156)

                        VStack(spacing: 16) {
                            remoteIconButton("gearshape.fill", "KEY_MENU")
                            remoteIconButton("xmark", "KEY_EXIT")
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Media playback bar
                    HStack(spacing: 8) {
                        mediaActionButton("backward.fill", "KEY_REWIND")
                        mediaActionButton("play.fill", "KEY_PLAY")
                        mediaActionButton("pause.fill", "KEY_PAUSE")
                        mediaActionButton("stop.fill", "KEY_STOP")
                        mediaActionButton("forward.fill", "KEY_FF")
                    }
                }
                .disabled(!store.connected)
            }

            // Swipe pad for focus navigation
            GlassCard {
                VStack(spacing: 8) {
                    HStack {
                        Label("Swipe Pad", systemImage: "hand.draw.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("Swipe to navigate · Tap for OK").font(.system(size: 9)).foregroundStyle(mutedInk)
                    }
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.08))
                        .overlay(
                            Image(systemName: "hand.draw")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(accent.opacity(0.7))
                        )
                        .frame(height: 84)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    let delta = CGSize(
                                        width: value.translation.width - swipeTranslation.width,
                                        height: value.translation.height - swipeTranslation.height
                                    )
                                    swipeTranslation = value.translation
                                    store.swipePointer(dx: delta.width, dy: delta.height)
                                }
                                .onEnded { _ in
                                    swipeTranslation = .zero
                                    store.endSwipe()
                                }
                        )
                        .simultaneousGesture(TapGesture().onEnded {
                            Haptic.press()
                            store.press("KEY_ENTER")
                        })
                }
                .disabled(!store.connected)
            }

            audioCard

            // Channel Up/Down
            HStack(spacing: 12) {
                Button {
                    Haptic.press()
                    store.press("KEY_CHDOWN")
                } label: {
                    Label("Channel −", systemImage: "chevron.down")
                        .frame(maxWidth: .infinity).frame(height: 38)
                }
                .buttonStyle(GlassButton(accent: accent))

                Button {
                    Haptic.press()
                    store.press("KEY_CHUP")
                } label: {
                    Label("Channel +", systemImage: "chevron.up")
                        .frame(maxWidth: .infinity).frame(height: 38)
                }
                .buttonStyle(GlassButton(accent: accent))
            }
            .disabled(!store.connected)

            // Text / Keyboard Input
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Text Input", systemImage: "keyboard")
                        .font(.system(size: 12, weight: .semibold))
                    HStack {
                        TextField("Type into TV text box", text: $text)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                            .onSubmit(sendText)

                        Button("Send", action: sendText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                            .disabled(text.isEmpty)

                        Button {
                            Haptic.press()
                            store.enterText()
                        } label: {
                            Image(systemName: "return")
                                .padding(8)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                    }
                }
                .disabled(!store.connected)
            }
        }
    }

    private func sendText() {
        guard !text.isEmpty else { return }
        Haptic.press()
        store.sendText(text)
        text = ""
    }

    private func dpadDirection(_ symbol: String, _ key: String) -> some View {
        Button {
            Haptic.press()
            store.press(key)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func remoteIconButton(_ symbol: String, _ key: String) -> some View {
        Button {
            Haptic.press()
            store.press(key)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(GlassButton(accent: accent))
    }

    private func mediaActionButton(_ symbol: String, _ key: String) -> some View {
        Button {
            Haptic.press()
            store.media(key)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .buttonStyle(GlassButton(accent: accent))
    }

    // MARK: - Apps Panel
    private var appsPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(mutedInk)
                TextField("Search \(store.shortcuts.count) apps", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(mutedInk)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(store.shortcuts.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }) { app in
                    let color = BrandTheme.forApp(app.id, title: app.title, icon: AppIcons.url(for: app)).color
                    let isFav = store.favorites.contains(app.id)
                    let isActive = store.displayForegroundID == app.id

                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Button {
                                Haptic.tap()
                                store.toggleFavorite(app)
                            } label: {
                                Image(systemName: isFav ? "star.fill" : "star")
                                    .font(.system(size: 11))
                                    .foregroundStyle(isFav ? color : mutedInk)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Haptic.press()
                            store.launch(app)
                        } label: {
                            VStack(spacing: 8) {
                                AppMark(app: app, size: 48)
                                    .shadow(color: color.opacity(0.24), radius: 8)
                                Text(app.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 28)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.connected)

                        if isActive {
                            Text("Active")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(color)
                        } else {
                            Color.clear.frame(height: 11)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isActive ? color : Color.white.opacity(0.08), lineWidth: isActive ? 1.5 : 0.8)
                    )
                    .contextMenu {
                        Button(isFav ? "Remove from favorites" : "Add to favorites") { store.toggleFavorite(app) }
                        Button("Hide from list") { store.setHidden(app, true) }
                    }
                }
            }

            if !store.hiddenApps.isEmpty {
                Button("Show \(store.hiddenApps.count) hidden apps") {
                    store.showHiddenApps()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent)
            }
        }
    }

    // MARK: - Inputs Panel
    private func active(_ input: TVInput) -> Bool { store.displayForegroundID == input.id }
    private func defaultLabel(_ input: TVInput) -> String { input.id == "TV" ? "Live TV" : input.id.replacingOccurrences(of: "HDMI", with: "HDMI ") }

    private var inputsPanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Inputs & Sources", systemImage: "cable.connector")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button {
                        Haptic.press()
                        store.press("KEY_SOURCE")
                    } label: {
                        Text("Source Menu")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .disabled(!store.connected)
                }

                ForEach(store.inputs) { input in
                    inputRow(input)
                }
            }
        }
    }

    private func inputRow(_ input: TVInput) -> some View {
        Button {
            Haptic.press()
            store.input(input)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(input.label.localizedCaseInsensitiveContains("PS5") ? Color(red: 0.05, green: 0.20, blue: 0.50) : Color.white.opacity(0.07))
                    if input.label.localizedCaseInsensitiveContains("PS5") || input.label.localizedCaseInsensitiveContains("PlayStation") {
                        BrandImage(name: "playstation", width: 22, height: 22)
                    } else if input.label.localizedCaseInsensitiveContains("Chromecast") {
                        BrandImage(name: "googlecast", width: 20, height: 20)
                    } else {
                        Image(systemName: input.id == "TV" ? "antenna.radiowaves.left.and.right" : "cable.connector")
                            .font(.system(size: 14))
                            .foregroundStyle(mutedInk)
                    }
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(input.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(input.id == "TV" ? "Antenna / Cable" : defaultLabel(input))
                        .font(.system(size: 10))
                        .foregroundStyle(mutedInk)
                }

                Spacer()

                if active(input) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(mutedInk)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).fill(active(input) ? accent.opacity(0.15) : Color.clear))
        }
        .buttonStyle(.plain)
        .disabled(!store.connected)
        .contextMenu {
            Button("Rename…") {
                renamingInput = input
                renameText = input.label == defaultLabel(input) ? "" : input.label
                showRenameAlert = true
            }
        }
    }

    // MARK: - Cast / Media Panel
    private var mediaPanel: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "airplay.video")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AirPlay Screen Mirroring")
                                .font(.system(size: 14, weight: .bold))
                            Text("Mirror iPhone screen to \(store.name)")
                                .font(.system(size: 10))
                                .foregroundStyle(mutedInk)
                        }
                    }
                    Text("Swipe down from the top right corner of your iPhone to open Control Center, tap Screen Mirroring, and select “\(store.name)”.")
                        .font(.system(size: 11))
                        .foregroundStyle(mutedInk)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Direct Media Casting (DLNA)", systemImage: "play.tv")
                        .font(.system(size: 14, weight: .bold))

                    if let file = store.mediaFile {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.lastPathComponent).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                Text(file.pathExtension.uppercased()).font(.system(size: 9)).foregroundStyle(mutedInk)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.12)))
                    }

                    Text(store.mediaStatus)
                        .font(.system(size: 11))
                        .foregroundStyle(mutedInk)

                    HStack {
                        Button("Choose File") {
                            showFilePicker = true
                        }
                        .buttonStyle(GlassButton(accent: accent))

                        Spacer()

                        Button(store.mediaBusy ? "Sending…" : "Play on TV") {
                            Haptic.press()
                            store.castMedia()
                        }
                        .buttonStyle(GlassButton(selected: true, accent: accent))
                        .disabled(!store.connected || store.mediaFile == nil || store.mediaBusy)
                    }

                    if store.casting {
                        HStack(spacing: 10) {
                            ForEach([("play.fill", "Play"), ("pause.fill", "Pause"), ("stop.fill", "Stop")], id: \.1) { symbol, action in
                                Button {
                                    Haptic.press()
                                    store.controlCast(action)
                                } label: {
                                    Image(systemName: symbol).frame(maxWidth: .infinity).frame(height: 32)
                                }
                                .buttonStyle(GlassButton(accent: accent))
                            }
                        }
                        .disabled(store.mediaBusy)
                    }
                }
            }
        }
    }

    // MARK: - Activity / Usage Panel
    private var usagePanel: some View {
        let totals = store.usage(days: usageDays)
        let total = totals.reduce(0) { $0 + $1.seconds }

        return VStack(spacing: 14) {
            Picker("Period", selection: $usageDays) {
                Text("Today").tag(1)
                Text("7 days").tag(7)
                Text("30 days").tag(30)
            }
            .pickerStyle(.segmented)

            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Screen Time")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(mutedInk)
                    Text(duration(total))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    Text("Usage tracked while connected")
                        .font(.system(size: 10))
                        .foregroundStyle(mutedInk)
                }
            }

            GlassCard {
                VStack(spacing: 14) {
                    ForEach(totals) { item in
                        let app = store.apps.first(where: { $0.id == item.id })
                        let color = BrandTheme.forApp(item.id, title: item.title, icon: app.flatMap(AppIcons.url)).color
                        VStack(spacing: 6) {
                            HStack {
                                if let app { AppMark(app: app, size: 24) }
                                Text(item.title).font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(duration(item.seconds)).font(.system(size: 11)).foregroundStyle(mutedInk)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.06))
                                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(item.seconds / max(total, 1)))
                                }
                            }
                            .frame(height: 4)
                        }
                    }

                    if totals.isEmpty {
                        Text("No activity recorded yet.")
                            .font(.system(size: 11))
                            .foregroundStyle(mutedInk)
                            .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes == 0 { return "\(Int(seconds))s" }
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    // MARK: - Connection Panel (When Disconnected)
    private var connectionPanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(store.status, systemImage: store.pairing ? "checkmark.shield.fill" : "wifi.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.pairing ? Color.green : Color.orange)

                Text(store.pairing ? "A permission prompt appears on your TV screen. Choose 'Allow' with your TV remote." : "Make sure your iPhone and TV are connected to the same Wi-Fi network.")
                    .font(.system(size: 11))
                    .foregroundStyle(mutedInk)

                Button(store.connecting ? "Connecting…" : "Connect to TV") {
                    Haptic.press()
                    if store.connecting { store.disconnect() }
                    else if store.host.isEmpty {
                        draftHost = store.host; draftName = store.name; draftMAC = store.mac
                        settings = true
                    } else { store.connect() }
                }
                .buttonStyle(GlassButton(selected: true, accent: accent))
            }
        }
    }

    // MARK: - Settings Panel
    private var settingsPanel: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TV Connection Settings")
                        .font(.system(size: 14, weight: .bold))

                    TextField("Device Name", text: $draftName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                    TextField("TV IP Address (e.g. 192.168.1.50)", text: $draftHost)
                        .textFieldStyle(.plain)
                        .keyboardType(.numbersAndPunctuation)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                    TextField("Wi-Fi MAC Address (for Wake-on-LAN)", text: $draftMAC)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                    Button("Save and Connect") {
                        Haptic.press()
                        store.disconnect()
                        store.host = draftHost.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Samsung TV" : draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.mac = draftMAC.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.connect()
                        settings = false
                    }
                    .buttonStyle(GlassButton(selected: true, accent: accent))
                    .disabled(!TizenConnection.localHost(draftHost.trimmingCharacters(in: .whitespacesAndNewlines)) || store.connecting)

                    if !store.host.isEmpty {
                        Button("Forget Pairing") {
                            showForgetConfirm = true
                        }
                        .foregroundStyle(.red)
                        .font(.system(size: 11, weight: .semibold))
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Button(store.discovering ? "Searching for TVs on Wi-Fi…" : "Find TVs on Local Network") {
                        Haptic.press()
                        store.discover()
                    }
                    .buttonStyle(GlassButton(accent: accent))
                    .disabled(store.discovering)

                    ForEach(store.devices) { device in
                        Button {
                            Haptic.press()
                            store.select(device)
                            settings = false
                        } label: {
                            HStack {
                                Text(device.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                Spacer()
                                Text(device.host).font(.system(size: 11)).foregroundStyle(mutedInk)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            GlassCard {
                Stepper(value: Binding(get: { store.hdmiCount }, set: store.setHDMICount), in: 1...4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HDMI Ports: \(store.hdmiCount)").font(.system(size: 13, weight: .semibold))
                        Text("Match the ports on your TV.").font(.system(size: 10)).foregroundStyle(mutedInk)
                    }
                }
            }
        }
    }

    // MARK: - Feedback Banner
    @ViewBuilder private var feedback: some View {
        if let error = store.error {
            GlassCard {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.system(size: 11)).foregroundStyle(.white)
                    Spacer()
                    Button {
                        store.error = nil
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(mutedInk)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if let notice = store.notice {
            Text(notice)
                .font(.system(size: 11))
                .foregroundStyle(mutedInk)
                .padding(.horizontal, 4)
        }
    }
}
