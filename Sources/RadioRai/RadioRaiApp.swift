import SwiftUI

@main
struct RadioRaiApp: App {
    @StateObject private var radio = RadioStore()
    @StateObject private var clock = NTPClock()

    var body: some Scene {
        Window("Radio Rai", id: "main") {
            MainView()
                .environmentObject(radio)
                .environmentObject(clock)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Aggiorna palinsesto") { Task { await radio.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarControlsView()
                .environmentObject(radio)
        } label: {
            Image(systemName: radio.isPlaying ? "waveform" : "dot.radiowaves.left.and.right")
                .help(radio.isPlaying ? "Radio Rai · \(radio.playingChannel ?? "In riproduzione")" : "Radio Rai")
        }
        .menuBarExtraStyle(.window)
    }
}
