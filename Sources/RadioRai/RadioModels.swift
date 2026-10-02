import Foundation

struct RadioChannel: Identifiable, Hashable {
    let name: String
    let program: String
    let streamURL: URL?

    var id: String { name }
}

struct ProgramInfo {
    var channel = ""
    var program = ""
    var episode = ""
    var description = ""
    var time = ""
    var book = ""
    var nextProgram = ""
    var nextTime = ""
    var hasAudio = false
}

enum RaiEndpoints {
    static let base = URL(string: "https://www.raiplaysound.it")!
    static let streams: [String: String] = [
        "Rai Radio 1": "https://icestreaming.rai.it/1.mp3",
        "Rai Radio 2": "https://icestreaming.rai.it/2.mp3",
        "Rai Radio 3": "https://icestreaming.rai.it/3.mp3",
        "Rai Isoradio": "https://icestreaming.rai.it/isoradio.mp3",
        "Rai Radio 3 Classica": "https://icestreaming.rai.it/5.mp3",
        "Rai Radio GR Parlamento": "https://icestreaming.rai.it/grparlamento.mp3",
        "Rai Radio Techete": "https://icestreaming.rai.it/techete.mp3",
        "Rai Radio Kids": "https://icestreaming.rai.it/kids.mp3",
        "Rai Radio Live Napoli": "https://icestreaming.rai.it/livenapoli.mp3",
        "Rai Radio Tutta Italiana": "https://icestreaming.rai.it/tuttaitaliana.mp3",
        "Rai Radio 1 Sport": "https://icestreaming.rai.it/13.mp3",
        "No Name Radio": "https://icestreaming.rai.it/15.mp3",
        "Rai Radio Südtirol": "http://radiobzlive.rai.it/RAIBZ_Livestream",
        "Rai Radio Trst A": "https://raievent9-live.akamaized.net/hls/live/619188/raievent9/raievent9/playlist.m3u8"
    ]
}
