import SwiftUI
import AppKit

enum Palette {
    static let ink = adaptive(light: NSColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 1), dark: NSColor(red: 0.92, green: 0.93, blue: 0.92, alpha: 1))
    static let muted = adaptive(light: NSColor(red: 0.48, green: 0.52, blue: 0.53, alpha: 1), dark: NSColor(red: 0.65, green: 0.68, blue: 0.69, alpha: 1))
    static let paper = adaptive(light: NSColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1), dark: NSColor(red: 0.09, green: 0.10, blue: 0.11, alpha: 1))
    static let panel = adaptive(light: .white, dark: NSColor(red: 0.14, green: 0.16, blue: 0.17, alpha: 1))
    static let accent = Color(red: 0.83, green: 0.25, blue: 0.17)
    static let line = adaptive(light: NSColor(red: 0.90, green: 0.89, blue: 0.86, alpha: 1), dark: NSColor(red: 0.23, green: 0.25, blue: 0.26, alpha: 1))

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

struct MainView: View {
    @EnvironmentObject private var radio: RadioStore
    @EnvironmentObject private var clock: NTPClock
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @State private var search = ""

    private var filteredChannels: [RadioChannel] {
        guard !search.isEmpty else { return radio.channels }
        return radio.channels.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.program.localizedCaseInsensitiveContains(search) }
    }

    private var italianDateStyle: Date.FormatStyle {
        Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: Locale(identifier: "it_IT"),
            timeZone: TimeZone(identifier: "Europe/Rome")!
        )
        .weekday(.wide).day().month(.wide)
    }

    private var italianTimeStyle: Date.FormatStyle {
        Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: Locale(identifier: "it_IT"),
            timeZone: TimeZone(identifier: "Europe/Rome")!
        )
        .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .background(Palette.paper)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .task {
            await radio.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(secondsUntilNextMinute))
                guard !Task.isCancelled else { return }
                await radio.refresh(silently: true)
            }
        }
        .alert("Connessione", isPresented: Binding(get: { radio.errorMessage != nil }, set: { if !$0 { radio.errorMessage = nil } })) {
            Button("OK", role: .cancel) { radio.errorMessage = nil }
            Button("Riprova") { Task { await radio.refresh() } }
        } message: { Text(radio.errorMessage ?? "") }
    }

    private var secondsUntilNextMinute: Double {
        let seconds = clock.now.timeIntervalSince1970
        let elapsedInMinute = seconds.truncatingRemainder(dividingBy: 60)
        return 60 - elapsedInMinute
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Palette.accent).frame(width: 38, height: 38)
                    Image(systemName: "waveform").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("radio rai").font(.system(size: 17, weight: .bold, design: .rounded)).tracking(-0.5)
                    Text("LA RADIO, COME VUOI").font(.system(size: 8, weight: .bold)).tracking(1.25).foregroundStyle(Palette.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 27).padding(.bottom, 25)

            HStack {
                Text("IN DIRETTA").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Palette.muted)
                Spacer()
                Button { Task { await radio.refresh() } } label: {
                    Image(systemName: radio.isLoading ? "arrow.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                }.buttonStyle(.plain).help("Aggiorna palinsesto")
            }.padding(.horizontal, 22).padding(.bottom, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Palette.muted)
                TextField("Cerca una stazione", text: $search).textFieldStyle(.plain).font(.system(size: 12))
            }
            .padding(10).background(Palette.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.line, lineWidth: 1))
            .padding(.horizontal, 16).padding(.bottom, 15)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, channel in
                        ChannelRow(channel: channel, number: index + 1, selected: radio.selectedChannel == channel.name) {
                            Task { await radio.select(channel) }
                        }
                    }
                }.padding(.horizontal, 10).padding(.bottom, 12)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 0.23, green: 0.63, blue: 0.43)).frame(width: 7, height: 7)
                    Text("Palinsesto RaiPlay Sound").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                }
                HStack(spacing: 8) {
                    Image(systemName: darkModeEnabled ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    Text("Tema scuro").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink)
                    Spacer()
                    Toggle("Tema scuro", isOn: $darkModeEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .help(darkModeEnabled ? "Passa al tema chiaro" : "Passa al tema scuro")
                }
            }.padding(.horizontal, 19).padding(.vertical, 14)
        }
        .frame(width: 260)
        .background(Palette.paper)
        .overlay(alignment: .trailing) { Rectangle().fill(Palette.line).frame(width: 1) }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 12)).foregroundStyle(Palette.accent)
                    Text("ASCOLTA LA RAI").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Palette.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(clock.now.formatted(italianDateStyle))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(clock.isSynchronized ? Color(red: 0.23, green: 0.63, blue: 0.43) : Palette.muted)
                            .frame(width: 5, height: 5)
                        Text(clock.now.formatted(italianTimeStyle))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.ink)
                    }
                    .help(clock.isSynchronized ? "Ora sincronizzata con ntp1.inrim.it" : "In attesa della sincronizzazione NTP")
                }
            }.padding(.horizontal, 36).padding(.top, 25).padding(.bottom, 18)

            Rectangle().fill(Palette.line).frame(height: 1)
            if let show = radio.currentProgram {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 7) {
                            Circle().fill(Palette.accent).frame(width: 7, height: 7)
                            Text(show.hasAudio ? "ULTIMA PUNTATA" : "ORA IN ONDA")
                                .font(.system(size: 10, weight: .bold)).tracking(1.45).foregroundStyle(Palette.accent)
                            if !show.time.isEmpty { Text("·  \(show.time)").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted) }
                        }
                        .padding(.top, 43)

                        Text(show.channel).font(.system(size: 44, weight: .bold, design: .rounded)).tracking(-2.3)
                            .foregroundStyle(Palette.ink).padding(.top, 13)
                        Text(show.program.isEmpty ? "Radio Rai" : show.program)
                            .font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.muted).padding(.top, 5)

                        HStack(alignment: .center, spacing: 22) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(red: 0.91, green: 0.34, blue: 0.23), Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                                Circle().stroke(.white.opacity(0.17), lineWidth: 1).padding(18)
                                Circle().stroke(.white.opacity(0.17), lineWidth: 1).padding(36)
                                Image(systemName: "waveform").font(.system(size: 58, weight: .light)).foregroundStyle(.white)
                            }
                            .frame(width: 190, height: 190).clipped()
                            VStack(alignment: .leading, spacing: 13) {
                                Text(show.episode.isEmpty ? "La voce della\nradio italiana" : show.episode)
                                    .font(.system(size: 27, weight: .semibold, design: .rounded)).tracking(-0.7).foregroundStyle(Palette.ink)
                                if !show.book.isEmpty && show.book != show.episode {
                                    Text(show.book.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.3).foregroundStyle(Palette.accent)
                                }
                                Text("Seleziona il tasto per sintonizzarti e ascoltare in diretta.")
                                    .font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                                Button(action: radio.togglePlayback) {
                                    HStack(spacing: 10) {
                                        Image(systemName: radio.isSelectedChannelPlaying ? "pause.fill" : "play.fill").font(.system(size: 12, weight: .bold))
                                        Text(radio.isSelectedChannelPlaying ? "Metti in pausa" : "Ascolta in diretta").font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white).padding(.horizontal, 18).frame(height: 43)
                                    .background(Palette.accent, in: Capsule())
                                }.buttonStyle(.plain).padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(20).background(Palette.panel, in: RoundedRectangle(cornerRadius: 28))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.line.opacity(0.75), lineWidth: 1))
                        .padding(.top, 30)

                        if !show.description.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionLabel("IL PROGRAMMA")
                                ForEach(Array(show.description.components(separatedBy: " // ").enumerated()), id: \.offset) { _, line in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: show.description.contains(" // ") ? "music.note" : "text.alignleft")
                                            .font(.system(size: 11)).foregroundStyle(Palette.accent).padding(.top, 3)
                                        Text(line.trimmingCharacters(in: .whitespacesAndNewlines)).font(.system(size: 13)).foregroundStyle(Palette.ink.opacity(0.82)).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 18)).padding(.top, 17)
                        }

                        if !show.nextProgram.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "clock").font(.system(size: 14)).foregroundStyle(Palette.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("A SEGUIRE").font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Palette.muted)
                                    Text(show.nextProgram).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                                }
                                Spacer()
                                Text(show.nextTime).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
                            }.padding(.horizontal, 18).padding(.vertical, 15)
                                .background(Palette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 15)).padding(.top, 15)
                        }
                    }
                    .padding(.horizontal, 36).padding(.bottom, 35)
                }
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(Palette.accent).scaleEffect(1.1)
                    Text(radio.isLoading ? "Carico il palinsesto…" : "Seleziona una stazione")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)
            playerBar
        }
        .background(Palette.paper.opacity(0.72))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .bold)).tracking(1.35).foregroundStyle(Palette.muted)
    }

    private var playerBar: some View { PlayerBar() }
}

private struct PlayerBar: View {
    @EnvironmentObject private var radio: RadioStore

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Palette.accent.opacity(0.11)).frame(width: 38, height: 38)
                    Image(systemName: "waveform").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text((radio.isPlaying ? radio.playingChannel : radio.selectedChannel) ?? "Radio Rai")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(radio.isPlaying ? "In riproduzione" : "Pronto all’ascolto")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer()
                if radio.isPlaying {
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(0..<5) { i in Capsule().fill(Palette.accent.opacity(0.7)).frame(width: 3, height: [9, 16, 11, 19, 8][i]) }
                    }.frame(height: 21).padding(.trailing, 4)
                }
                HStack(spacing: 7) {
                    Image(systemName: volumeSymbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Slider(value: Binding(
                        get: { radio.volume },
                        set: { radio.setVolume($0) }
                    ), in: 0...1)
                    .frame(width: 92)
                    .accessibilityLabel("Volume")
                }
                .help("Volume: \(Int(radio.volume * 100))%")
                Button(action: handlePlaybackButton) {
                    Image(systemName: radio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 37, height: 37).background(Palette.accent, in: Circle())
                }.buttonStyle(.plain).help(radio.isPlaying ? "Metti in pausa" : "Ascolta")
            }
            .padding(.horizontal, 25).padding(.vertical, 13)
        }
        .background(Palette.panel)
    }

    private func handlePlaybackButton() {
        if radio.isPlaying {
            radio.pausePlayback()
        } else {
            radio.togglePlayback()
        }
    }

    private var volumeSymbol: String {
        if radio.volume == 0 { return "speaker.slash.fill" }
        if radio.volume < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }
}

private struct ChannelRow: View {
    let channel: RadioChannel
    let number: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(selected ? Palette.accent : Palette.panel).frame(width: 34, height: 34)
                    Text(String(format: "%02d", number)).font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? .white : Palette.muted)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(channel.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(channel.program).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected { Circle().fill(Palette.accent).frame(width: 6, height: 6) }
            }
            .padding(.horizontal, 9).padding(.vertical, 8)
            .background(selected ? Palette.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}
