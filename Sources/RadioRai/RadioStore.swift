import AVFoundation
import Combine
import Foundation

@MainActor
final class RadioStore: ObservableObject {
    @Published private(set) var channels: [RadioChannel] = []
    @Published private(set) var selectedChannel: String?
    @Published private(set) var currentProgram: ProgramInfo?
    @Published private(set) var isPlaying = false
    @Published private(set) var playingChannel: String?
    @Published private(set) var isLoading = false
    @Published private(set) var volume = 0.7 {
        didSet { player.volume = Float(volume) }
    }
    @Published var errorMessage: String?

    private let player = AVPlayer()

    init() {
        player.volume = Float(volume)
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
    }

    func refresh(silently: Bool = false) async {
        if !silently { isLoading = true }
        defer { if !silently { isLoading = false } }
        do {
            let data = try await request(URL(string: "/palinsesto/onAir.json", relativeTo: RaiEndpoints.base)!)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let items = root?["on_air"] as? [[String: Any]] ?? []
            let newChannels = items.compactMap { item -> RadioChannel? in
                guard let name = item["channel"] as? String else { return nil }
                let current = item["currentItem"] as? [String: Any] ?? [:]
                let streamURL = RaiEndpoints.streams[name].flatMap { URL(string: $0) }
                return RadioChannel(name: name, program: current["name"] as? String ?? "Programma in onda",
                                    streamURL: streamURL)
            }
            channels = newChannels
            if selectedChannel == nil || !newChannels.contains(where: { $0.name == selectedChannel }) {
                selectedChannel = newChannels.first?.name
            }
            if let selectedChannel { await loadProgram(for: selectedChannel, onAir: items) }
            errorMessage = nil
        } catch {
            if !silently {
                errorMessage = "Impossibile caricare il palinsesto. Controlla la connessione e riprova."
            }
        }
    }

    func select(_ channel: RadioChannel) async {
        selectedChannel = channel.name
        await loadProgram(for: channel.name)
    }

    var isSelectedChannelPlaying: Bool {
        isPlaying && playingChannel == selectedChannel
    }

    func togglePlayback() {
        guard let channel = channels.first(where: { $0.name == selectedChannel }), let url = channel.streamURL else {
            errorMessage = "Il flusso audio di questo canale non è disponibile."
            return
        }
        if isSelectedChannelPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            player.play()
            playingChannel = channel.name
            isPlaying = true
        }
    }

    func pausePlayback() {
        guard isPlaying else { return }
        player.pause()
        isPlaying = false
    }

    private func loadProgram(for channel: String, onAir cachedItems: [[String: Any]]? = nil) async {
        do {
            let items: [[String: Any]]
            if let cachedItems { items = cachedItems }
            else {
                let data = try await request(URL(string: "/palinsesto/onAir.json", relativeTo: RaiEndpoints.base)!)
                items = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["on_air"] as? [[String: Any]] ?? []
            }
            guard let item = items.first(where: { $0["channel"] as? String == channel }),
                  let current = item["currentItem"] as? [String: Any] else { return }

            var detail: [String: Any]?
            if let path = (current["program"] as? [String: Any])?["path_id"] as? String,
               let url = URL(string: path, relativeTo: RaiEndpoints.base) {
                let data = try? await request(url)
                detail = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            }
            let card = ((detail?["block"] as? [String: Any])?["cards"] as? [[String: Any]])?.first ?? [:]
            let episode = current["episode_title"] as? String ?? ""
            let cardTitle = card["episode_title"] as? String ?? card["toptitle"] as? String ?? ""
            let live = !(current["has_audio"] as? Bool ?? false)
            let supplement = episode.isEmpty || (!live && episode.isEmpty)
            let next = item["nextItem"] as? [String: Any] ?? [:]
            currentProgram = ProgramInfo(
                channel: channel,
                program: current["name"] as? String ?? "",
                episode: supplement ? cardTitle : episode,
                description: (current["description"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (card["description"] as? String ?? ""),
                time: current["time_interval"] as? String ?? "",
                book: card["toptitle"] as? String ?? "",
                nextProgram: next["name"] as? String ?? "",
                nextTime: next["time_interval"] as? String ?? "",
                hasAudio: !live
            )
            errorMessage = nil
        } catch {
            errorMessage = "Non riesco a recuperare i dettagli del programma."
        }
    }

    private func request(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) == true else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
