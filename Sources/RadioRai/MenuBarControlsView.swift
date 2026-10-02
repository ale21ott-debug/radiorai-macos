import SwiftUI
import AppKit

struct MenuBarControlsView: View {
    @EnvironmentObject private var radio: RadioStore
    @Environment(\.openWindow) private var openWindow

    private var volumeSymbol: String {
        if radio.volume == 0 { return "speaker.slash.fill" }
        if radio.volume < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 11) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Palette.accent, Palette.accent.opacity(0.15))
                VStack(alignment: .leading, spacing: 3) {
                    Text(radio.isPlaying ? (radio.playingChannel ?? "Radio Rai") : (radio.selectedChannel ?? "Radio Rai"))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(radio.isPlaying ? "In riproduzione" : "In pausa")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if radio.isPlaying,
               radio.playingChannel == radio.selectedChannel,
               let program = radio.currentProgram,
               !program.program.isEmpty {
                Text(program.program)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !radio.channels.isEmpty {
                Picker("Stazione", selection: Binding(
                    get: { radio.selectedChannel ?? "" },
                    set: { name in
                        guard let channel = radio.channels.first(where: { $0.name == name }) else { return }
                        Task { await radio.select(channel) }
                    }
                )) {
                    ForEach(radio.channels) { channel in
                        Text(channel.name).tag(channel.name)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            HStack(spacing: 9) {
                Image(systemName: volumeSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { radio.volume },
                    set: { radio.setVolume($0) }
                ), in: 0...1)
                .accessibilityLabel("Volume")
                Text("\(Int(radio.volume * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 31, alignment: .trailing)
            }

            HStack(spacing: 9) {
                Button {
                    if radio.isPlaying {
                        radio.pausePlayback()
                    } else {
                        radio.togglePlayback()
                    }
                } label: {
                    Label(radio.isPlaying ? "Pausa" : "Ascolta", systemImage: radio.isPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)

                if radio.isPlaying, radio.selectedChannel != radio.playingChannel {
                    Button {
                        radio.togglePlayback()
                    } label: {
                        Label("Passa", systemImage: "arrow.right.to.line")
                    }
                    .buttonStyle(.bordered)
                    .help("Riproduci la stazione selezionata")
                }
            }

            Divider()

            Button("Apri Radio Rai") {
                showMainWindow()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
        }
        .padding(16)
        .frame(width: 280)
        .task {
            if radio.channels.isEmpty { await radio.refresh() }
        }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Radio Rai" }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
