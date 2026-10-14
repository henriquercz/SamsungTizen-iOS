import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let mutedInk = Color.white.opacity(0.55)

private enum RemoteTab: String, CaseIterable, Identifiable {
    case home = "TV", remote = "Controle", apps = "Apps", usage = "Atividade"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: return "tv"
        case .remote: return "dpad"
        case .apps: return "square.grid.2x2"
        case .usage: return "chart.bar.xaxis"
        }
    }
}

private enum Haptic {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let strong = UIImpactFeedbackGenerator(style: .heavy)
    static func prepare() { light.prepare(); medium.prepare() }
    static func tap() { light.impactOccurred(); light.prepare() }
    static func press() { medium.impactOccurred(); medium.prepare() }
    static func heavy() { strong.impactOccurred() }
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
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    var width: CGFloat? = 28
    var height: CGFloat? = 28
    var contentMode: ContentMode = .fit
    var body: some View {
        Group {
            if let url = AppResources.bundle.url(forResource: name, withExtension: "png", subdirectory: "AppAssets"),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().interpolation(.high).aspectRatio(contentMode: contentMode)
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
    @State private var showNumberPad = false
    @AppStorage("touchProbe") private var touchProbe = false

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

            if touchProbe {
                TouchProbe()
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                // Floating Liquid Glass Navbar (iOS 2026 Style)
                floatingHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // Sleep Timer Live Glass Pill
                if store.sleepTimerSecondsRemaining != nil {
                    sleepTimerActiveBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.sleepTimerSecondsRemaining != nil)

            // Floating Liquid Glass Tab Bar (iOS 2026 Bottom Dock)
            VStack {
                Spacer()
                floatingTabBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
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
        .alert("Renomear Entrada", isPresented: $showRenameAlert) {
            TextField("Nome da entrada (ex: PS5)", text: $renameText)
            Button("Salvar") {
                if let input = renamingInput {
                    store.renameInput(input, to: renameText)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Digite um nome personalizado para esta porta de entrada da TV.")
        }
        .confirmationDialog("Esquecer Pareamento da TV?", isPresented: $showForgetConfirm, titleVisibility: .visible) {
            Button("Esquecer pareamento", role: .destructive) {
                store.forgetPairing()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O token e certificado salvos para esta TV serão removidos deste dispositivo.")
        }
    }

    // MARK: - Floating Liquid Glass Header (Top Navbar)
    private var floatingHeader: some View {
        HStack(spacing: 12) {
            // App Logo in subtle liquid glass container
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.24), .white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                BrandImage(name: "logo", width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

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

            // Sleep Timer Menu Button
            sleepTimerHeaderButton

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

    // MARK: - Sleep Timer UI
    @ViewBuilder private var sleepTimerPresetsMenu: some View {
        Section("Desligamento Automático") {
            Button {
                Haptic.press()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    store.startSleepTimer(minutes: 15)
                }
            } label: {
                Label("15 minutos", systemImage: "timer")
            }
            Button {
                Haptic.press()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    store.startSleepTimer(minutes: 30)
                }
            } label: {
                Label("30 minutos", systemImage: "timer")
            }
            Button {
                Haptic.press()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    store.startSleepTimer(minutes: 45)
                }
            } label: {
                Label("45 minutos", systemImage: "timer")
            }
            Button {
                Haptic.press()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    store.startSleepTimer(minutes: 60)
                }
            } label: {
                Label("1 hora (60 min)", systemImage: "clock")
            }
            Button {
                Haptic.press()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    store.startSleepTimer(minutes: 90)
                }
            } label: {
                Label("1 hora e meia (90 min)", systemImage: "clock")
            }
            Button {
                Haptic.press()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    store.startSleepTimer(minutes: 120)
                }
            } label: {
                Label("2 horas (120 min)", systemImage: "moon.zzz")
            }
        }

        if store.sleepTimerSecondsRemaining != nil {
            Section {
                Button(role: .destructive) {
                    Haptic.tap()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        store.cancelSleepTimer()
                    }
                } label: {
                    Label("Cancelar Timer", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var sleepTimerHeaderButton: some View {
        Menu {
            sleepTimerPresetsMenu
        } label: {
            ZStack {
                Circle()
                    .fill(store.sleepTimerSecondsRemaining != nil ? accent.opacity(0.25) : Color.white.opacity(0.08))
                Image(systemName: store.sleepTimerSecondsRemaining != nil ? "timer" : "moon.zzz")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(store.sleepTimerSecondsRemaining != nil ? accent : mutedInk)
            }
            .frame(width: 38, height: 38)
            .overlay(
                Circle().strokeBorder(
                    store.sleepTimerSecondsRemaining != nil ? accent.opacity(0.5) : Color.white.opacity(0.12),
                    lineWidth: 0.8
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.sleepTimerSecondsRemaining != nil ? "Timer ativo: \(store.formattedSleepTimer)" : "Timer de desligamento")
    }

    private var sleepTimerQuickButton: some View {
        Menu {
            sleepTimerPresetsMenu
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.sleepTimerSecondsRemaining != nil ? "timer" : "moon.zzz")
                    .font(.system(size: 10, weight: .semibold))
                Text(store.sleepTimerSecondsRemaining != nil ? store.formattedSleepTimer : "Timer")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(store.sleepTimerSecondsRemaining != nil ? accent : mutedInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(store.sleepTimerSecondsRemaining != nil ? accent.opacity(0.18) : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(store.sleepTimerSecondsRemaining != nil ? accent.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    private var sleepTimerActiveBanner: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Text("Desliga em")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(store.formattedSleepTimer)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }

            Spacer()

            Button {
                Haptic.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    store.cancelSleepTimer()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                    Text("Cancelar")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.red.opacity(0.9))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.red.opacity(0.16)))
                .overlay(Capsule().strokeBorder(Color.red.opacity(0.35), lineWidth: 0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.5), accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: accent.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    // MARK: - Floating Liquid Glass Tab Bar (Bottom Dock)
    private var floatingTabBar: some View {
        HStack(spacing: 4) {
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
                            Label("Favoritos", systemImage: "star.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(accent)
                            Spacer()
                            Button {
                                Haptic.tap()
                                tab = .apps
                            } label: {
                                Text("Ver todos").font(.system(size: 11, weight: .medium)).foregroundStyle(mutedInk)
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
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .blur(radius: 36)

                    BrandImage(name: "tv-hero", width: nil, height: 155)
                        .frame(maxWidth: .infinity)

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
                .frame(maxWidth: .infinity)

                HStack {
                    Circle().fill(store.connected ? accent : mutedInk).frame(width: 6, height: 6)
                    Text(store.connected ? (store.currentAppID != nil || store.currentInput != nil ? "Ativo na TV" : "Conectado") : "Desconectado")
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
                    Text("Volume da TV").font(.system(size: 13, weight: .semibold))
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
                    Text(store.muted ? "Mudo" : store.hasVolume || !store.connected ? "Alto-falantes da TV" : "Botões de volume funcionam via controle.")
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

    // MARK: - Remote Panel (Full Tactile Remote)
    private var remotePanel: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(spacing: 18) {
                    HStack(spacing: 8) {
                        Text(store.currentApp.isEmpty ? "Controle Samsung" : store.currentApp)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                        Spacer()
                        sleepTimerQuickButton
                        Circle().fill(store.connected ? Color.green : Color.orange).frame(width: 6, height: 6)
                        Text(store.connected ? "Pronto" : "Desconectado").font(.system(size: 10)).foregroundStyle(mutedInk)
                    }

                    // D-Pad and Core Action cluster
                    HStack(spacing: 14) {
                        VStack(spacing: 20) {
                            remoteIconButton("house.fill", "KEY_HOME", label: "Início")
                            remoteIconButton("arrow.uturn.backward", "KEY_RETURN", label: "Voltar")
                        }

                        // Circular D-Pad
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.white.opacity(0.25), .white.opacity(0.06)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )

                            VStack {
                                dpadDirection("chevron.up", "KEY_UP", label: "Para cima")
                                Spacer()
                                dpadDirection("chevron.down", "KEY_DOWN", label: "Para baixo")
                            }
                            .padding(10)

                            HStack {
                                dpadDirection("chevron.left", "KEY_LEFT", label: "Para a esquerda")
                                Spacer()
                                dpadDirection("chevron.right", "KEY_RIGHT", label: "Para a direita")
                            }
                            .padding(10)

                            // Center OK Button
                            Button {
                                Haptic.press()
                                store.press("KEY_ENTER")
                            } label: {
                                Text("OK")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(width: 58, height: 58)
                                    .background(Circle().fill(accent.opacity(0.26)))
                                    .overlay(Circle().strokeBorder(accent.opacity(0.65), lineWidth: 1.2))
                                    .foregroundStyle(accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("OK")
                            .accessibilityHint("Confirmar seleção")
                        }
                        .frame(width: 184, height: 184)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Navegação")

                        VStack(spacing: 20) {
                            remoteIconButton("gearshape.fill", "KEY_MENU", label: "Menu")
                            remoteIconButton("xmark", "KEY_EXIT", label: "Sair")
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Ergonomic Tactile Rockers & Media Controls
                    HStack(alignment: .center, spacing: 12) {
                        volumeRockerPill
                        centerPlaybackCluster
                        channelRockerPill
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!store.connected)
            }

            // Quick App & Input buttons
            quickButtonsCard

            // Numbers Pad
            numberPadCard

            // Swipe pad for focus navigation
            GlassCard {
                VStack(spacing: 8) {
                    HStack {
                        Label("Área de Navegação", systemImage: "hand.draw.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("Deslize para navegar · Toque para OK").font(.system(size: 9)).foregroundStyle(mutedInk)
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
                            DragGesture(minimumDistance: 14)
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

            // Text / Keyboard Input
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Teclado", systemImage: "keyboard")
                        .font(.system(size: 12, weight: .semibold))
                    HStack {
                        TextField("Digite o texto para a TV...", text: $text)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                            .onSubmit(sendText)

                        Button("Enviar", action: sendText)
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
                        .accessibilityLabel("Confirmar texto")
                    }
                }
                .disabled(!store.connected)
            }
        }
    }

    private var quickButtonsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Acesso Rápido", systemImage: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 8) {
                    Button {
                        Haptic.press()
                        store.press("KEY_TV")
                    } label: {
                        Text("TV Aberta")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                    }
                    .buttonStyle(GlassButton(accent: accent))

                    if let youtube = store.shortcuts.first(where: { $0.title.localizedCaseInsensitiveContains("youtube") }) {
                        Button {
                            Haptic.press()
                            store.launch(youtube)
                        } label: {
                            Text("YouTube")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                        }
                        .buttonStyle(GlassButton(accent: Color.red))
                    } else {
                        Button {
                            Haptic.press()
                            store.press("KEY_GUIDE")
                        } label: {
                            Text("Guia")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                        }
                        .buttonStyle(GlassButton(accent: accent))
                    }

                    if let netflix = store.shortcuts.first(where: { $0.title.localizedCaseInsensitiveContains("netflix") }) {
                        Button {
                            Haptic.press()
                            store.launch(netflix)
                        } label: {
                            Text("Netflix")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                        }
                        .buttonStyle(GlassButton(accent: Color.red))
                    } else {
                        Button {
                            Haptic.press()
                            store.press("KEY_SOURCE")
                        } label: {
                            Text("Entradas")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                        }
                        .buttonStyle(GlassButton(accent: accent))
                    }
                }
            }
            .disabled(!store.connected)
        }
    }

    private var numberPadCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Teclado Numérico", systemImage: "circle.grid.3x3.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button {
                        Haptic.tap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showNumberPad.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(showNumberPad ? "Ocultar" : "Mostrar")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: showNumberPad ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(accent)
                    }
                }

                if showNumberPad {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(1...9, id: \.self) { num in
                            Button("\(num)") {
                                Haptic.press()
                                store.press("KEY_\(num)")
                            }
                            .buttonStyle(GlassButton(accent: accent))
                            .frame(height: 38)
                        }

                        Button("Guia") {
                            Haptic.press()
                            store.press("KEY_GUIDE")
                        }
                        .buttonStyle(GlassButton(accent: accent))
                        .frame(height: 38)

                        Button("0") {
                            Haptic.press()
                            store.press("KEY_0")
                        }
                        .buttonStyle(GlassButton(accent: accent))
                        .frame(height: 38)

                        Button("Entradas") {
                            Haptic.press()
                            store.press("KEY_SOURCE")
                        }
                        .buttonStyle(GlassButton(accent: accent))
                        .frame(height: 38)
                    }
                    .padding(.top, 4)
                }
            }
            .disabled(!store.connected)
        }
    }

    private func sendText() {
        guard !text.isEmpty else { return }
        Haptic.press()
        store.sendText(text)
        text = ""
    }

    // MARK: - Rockers & Center Controls
    private var volumeRockerPill: some View {
        VStack(spacing: 0) {
            Button {
                Haptic.press()
                store.volumeStep(true)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 52, height: 44)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Aumentar volume")

            Divider().background(Color.white.opacity(0.12)).frame(width: 34)

            Button {
                Haptic.press()
                store.toggleMute()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: store.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(store.muted ? .red : mutedInk)
                    if store.hasVolume {
                        Text("\(Int(store.volume))")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(store.muted ? .red : accent)
                    }
                }
                .frame(width: 52, height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.muted ? "Desativar mudo" : "Mudo")

            Divider().background(Color.white.opacity(0.12)).frame(width: 34)

            Button {
                Haptic.press()
                store.volumeStep(false)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 52, height: 44)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Diminuir volume")
        }
        .frame(width: 52)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
        )
    }

    private var channelRockerPill: some View {
        VStack(spacing: 0) {
            Button {
                Haptic.press()
                store.press("KEY_CHUP")
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 52, height: 44)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Canal para cima")

            Divider().background(Color.white.opacity(0.12)).frame(width: 34)

            Button {
                Haptic.press()
                store.press("KEY_GUIDE")
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 13))
                    Text("Guia")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(mutedInk)
                .frame(width: 52, height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Guia de canais")

            Divider().background(Color.white.opacity(0.12)).frame(width: 34)

            Button {
                Haptic.press()
                store.press("KEY_CHDOWN")
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 52, height: 44)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .buttonRepeatBehavior(.enabled)
            .accessibilityLabel("Canal para baixo")
        }
        .frame(width: 52)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
        )
    }

    private var centerPlaybackCluster: some View {
        VStack(spacing: 10) {
            Button {
                Haptic.press()
                store.press("KEY_SOURCE")
            } label: {
                Label("Entradas", systemImage: "cable.connector")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(GlassButton(accent: accent))

            HStack(spacing: 8) {
                Button {
                    Haptic.press()
                    store.media("KEY_REWIND")
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(GlassButton(accent: accent))
                .accessibilityLabel("Retroceder")

                Button {
                    Haptic.press()
                    store.media("KEY_PLAY")
                } label: {
                    Image(systemName: "playpause.fill")
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(GlassButton(selected: true, accent: accent))
                .accessibilityLabel("Reproduzir ou pausar")

                Button {
                    Haptic.press()
                    store.media("KEY_FF")
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                }
                .buttonStyle(GlassButton(accent: accent))
                .accessibilityLabel("Avançar")
            }

            Button {
                Haptic.press()
                store.press("KEY_INFO")
            } label: {
                Label("Info", systemImage: "info.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(mutedInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func dpadDirection(_ symbol: String, _ key: String, label: String = "") -> some View {
        Button {
            Haptic.press()
            store.press(key)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? key : label)
    }

    private func remoteIconButton(_ symbol: String, _ key: String, label: String = "") -> some View {
        Button {
            Haptic.press()
            store.press(key)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(GlassButton(accent: accent))
        .accessibilityLabel(label.isEmpty ? key : label)
    }

    // MARK: - Apps Panel
    private var appsPanel: some View {
        let filtered = store.shortcuts.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }

        return VStack(spacing: 14) {
            HStack {
                Label("Aplicativos Instalados", systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
                Text("\(store.shortcuts.count) disponíveis")
                    .font(.system(size: 11))
                    .foregroundStyle(mutedInk)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(mutedInk)
                TextField("Buscar aplicativos...", text: $search)
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

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(mutedInk)
                    Text("Nenhum aplicativo encontrado")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(mutedInk)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                    ForEach(filtered) { app in
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
                                Text("Ativo")
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
                            Button("Abrir na TV") { store.launch(app) }
                            Button(isFav ? "Remover dos favoritos" : "Adicionar aos favoritos") { store.toggleFavorite(app) }
                            Button("Ocultar da lista") { store.setHidden(app, true) }
                        }
                    }
                }
            }

            if !store.hiddenApps.isEmpty {
                Button("Mostrar \(store.hiddenApps.count) aplicativos ocultos") {
                    store.showHiddenApps()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent)
            }
        }
    }

    // MARK: - Inputs Panel
    private func active(_ input: TVInput) -> Bool { store.displayForegroundID == input.id }
    private func defaultLabel(_ input: TVInput) -> String { input.id == "TV" ? "TV Aberta" : input.id.replacingOccurrences(of: "HDMI", with: "HDMI ") }

    private var inputsPanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Entradas e Fontes", systemImage: "cable.connector")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button {
                        Haptic.press()
                        store.press("KEY_SOURCE")
                    } label: {
                        Text("Menu de Entradas")
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
        let deviceType = ConnectedDeviceType.detect(from: input.label)
        return Button {
            Haptic.press()
            store.input(input)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(deviceType.isRecognized ? deviceType.accentColor.opacity(0.18) : Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(deviceType.isRecognized ? deviceType.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                    if deviceType.isRecognized {
                        Image(systemName: deviceType.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(deviceType.accentColor)
                    } else if input.id == "TV" {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14))
                            .foregroundStyle(mutedInk)
                    } else {
                        Image(systemName: deviceType.symbol)
                            .font(.system(size: 14))
                            .foregroundStyle(mutedInk)
                    }
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(input.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        if deviceType.isRecognized {
                            HStack(spacing: 3) {
                                Image(systemName: deviceType.symbol)
                                    .font(.system(size: 8, weight: .bold))
                                Text(deviceType.rawValue)
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(deviceType.accentColor.opacity(0.20), in: Capsule())
                            .overlay(Capsule().strokeBorder(deviceType.accentColor.opacity(0.4), lineWidth: 0.6))
                            .foregroundStyle(deviceType.accentColor)
                        }
                    }
                    Text(input.id == "TV" ? "Antena / Cabo" : defaultLabel(input))
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
            Button("Renomear Entrada…") {
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
                            Text("Espelhamento de Tela (AirPlay)")
                                .font(.system(size: 14, weight: .bold))
                            Text("Espelhar tela do iPhone na \(store.name)")
                                .font(.system(size: 10))
                                .foregroundStyle(mutedInk)
                        }
                    }
                    Text("Deslize do canto superior direito do seu iPhone para abrir a Central de Controle, toque em Espelhar a Tela e selecione “\(store.name)”.")
                        .font(.system(size: 11))
                        .foregroundStyle(mutedInk)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Transmitir Mídia (DLNA)", systemImage: "play.tv")
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
                        Button("Escolher Arquivo") {
                            showFilePicker = true
                        }
                        .buttonStyle(GlassButton(accent: accent))

                        Spacer()

                        Button(store.mediaBusy ? "Transmitindo para TV..." : "Abrir na TV") {
                            Haptic.press()
                            store.castMedia()
                        }
                        .buttonStyle(GlassButton(selected: true, accent: accent))
                        .disabled(!store.connected || store.mediaFile == nil || store.mediaBusy)
                    }

                    if store.casting {
                        HStack(spacing: 10) {
                            ForEach([("play.fill", "Play", "Reproduzir"), ("pause.fill", "Pause", "Pausar"), ("stop.fill", "Stop", "Parar transmissão")], id: \.1) { symbol, action, label in
                                Button {
                                    Haptic.press()
                                    store.controlCast(action)
                                } label: {
                                    Image(systemName: symbol).frame(maxWidth: .infinity).frame(height: 32)
                                }
                                .buttonStyle(GlassButton(accent: accent))
                                .accessibilityLabel(label)
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
            Picker("Período", selection: $usageDays) {
                Text("Hoje").tag(1)
                Text("Últimos 7 dias").tag(7)
                Text("Últimos 30 dias").tag(30)
            }
            .pickerStyle(.segmented)

            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tempo de tela")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(mutedInk)
                    Text(duration(total))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    Text("Tempo monitorado enquanto a TV esteve conectada")
                        .font(.system(size: 10))
                        .foregroundStyle(mutedInk)
                }
            }

            GlassCard {
                VStack(spacing: 14) {
                    HStack {
                        Label("Histórico de Atividade", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accent)
                        Spacer()
                        Text("Mais usados")
                            .font(.system(size: 11))
                            .foregroundStyle(mutedInk)
                    }

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
                        Text("Nenhum histórico de atividade registrado ainda.")
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

                Text(store.pairing ? "Uma solicitação de pareamento apareceu na sua TV. Escolha 'Permitir' usando o controle remoto físico." : "Certifique-se de que o seu iPhone e a TV estejam conectados à mesma rede Wi-Fi.")
                    .font(.system(size: 11))
                    .foregroundStyle(mutedInk)

                Button(store.connecting ? "Conectando…" : "Conectar à TV") {
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
                    Text("Configurações da TV")
                        .font(.system(size: 14, weight: .bold))

                    TextField("Nome da TV", text: $draftName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                    TextField("Endereço IP (ex: 192.0.2.1)", text: $draftHost)
                        .textFieldStyle(.plain)
                        .keyboardType(.numbersAndPunctuation)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                    TextField("Endereço MAC Wi-Fi (para Wake-on-LAN)", text: $draftMAC)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))

                    Button("Salvar e Conectar") {
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
                        Button("Esquecer pareamento") {
                            showForgetConfirm = true
                        }
                        .foregroundStyle(.red)
                        .font(.system(size: 11, weight: .semibold))
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Button(store.discovering ? "Buscando TVs na rede Wi-Fi…" : "Buscar TVs na Rede Local") {
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
                        Text("Portas HDMI: \(store.hdmiCount)").font(.system(size: 13, weight: .semibold))
                        Text("Configure de acordo com as portas físicas da sua TV.").font(.system(size: 10)).foregroundStyle(mutedInk)
                    }
                }
            }

            GlassCard {
                DiagnosticsCard(store: store)
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
