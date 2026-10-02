import Combine
import Darwin
import Foundation

@MainActor
final class NTPClock: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var isSynchronized = false

    private var referenceDate = Date()
    private var referenceUptime = ProcessInfo.processInfo.systemUptime

    init() {
        Task { [weak self] in
            guard let self else { return }
            await synchronize()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3_600))
                guard !Task.isCancelled else { return }
                await synchronize()
            }
        }

        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                tick()
            }
        }
    }

    func synchronize() async {
        do {
            let serverTime = try await NTPClient.currentTime()
            referenceDate = serverTime
            referenceUptime = ProcessInfo.processInfo.systemUptime
            now = serverTime
            isSynchronized = true
        } catch {
            if !isSynchronized {
                referenceDate = Date()
                referenceUptime = ProcessInfo.processInfo.systemUptime
                now = referenceDate
            }
        }
    }

    private func tick() {
        let elapsed = ProcessInfo.processInfo.systemUptime - referenceUptime
        now = referenceDate.addingTimeInterval(elapsed)
    }
}

private enum NTPClient {
    private static let ntpEpochOffset: TimeInterval = 2_208_988_800

    static func currentTime() async throws -> Date {
        try await Task.detached(priority: .utility) {
            try queryServer()
        }.value
    }

    private static func queryServer() throws -> Date {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_UDP

        var resolvedAddress: UnsafeMutablePointer<addrinfo>?
        let resolution = getaddrinfo("ntp1.inrim.it", "123", &hints, &resolvedAddress)
        guard resolution == 0, let firstAddress = resolvedAddress else {
            let reason = String(cString: gai_strerror(resolution))
            throw NSError(domain: "NTPClock", code: Int(resolution), userInfo: [NSLocalizedDescriptionKey: reason])
        }
        defer { freeaddrinfo(firstAddress) }

        var address = firstAddress
        var lastSocketError = EHOSTUNREACH
        while true {
            let entry = address.pointee
            let descriptor = socket(entry.ai_family, entry.ai_socktype, entry.ai_protocol)
            if descriptor >= 0 {
                defer { close(descriptor) }

                var timeout = timeval(tv_sec: 3, tv_usec: 0)
                _ = setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

                var request = [UInt8](repeating: 0, count: 48)
                request[0] = 0x23 // NTP version 4, client mode.
                let requestSentAt = ProcessInfo.processInfo.systemUptime
                let sent = request.withUnsafeBytes { bytes in
                    sendto(descriptor, bytes.baseAddress, bytes.count, 0, entry.ai_addr, entry.ai_addrlen)
                }
                guard sent == request.count else {
                    lastSocketError = errno
                    address = entry.ai_next
                    if address == nil { break }
                    continue
                }

                var response = [UInt8](repeating: 0, count: 48)
                let received = response.withUnsafeMutableBytes { bytes in
                    recv(descriptor, bytes.baseAddress, bytes.count, 0)
                }
                guard received >= 48 else {
                    lastSocketError = errno == 0 ? ETIMEDOUT : errno
                    address = entry.ai_next
                    if address == nil { break }
                    continue
                }

                let mode = response[0] & 0x07
                let leapIndicator = response[0] >> 6
                let stratum = response[1]
                guard mode == 4, leapIndicator != 3, (1...15).contains(stratum) else {
                    throw NSError(domain: "NTPClock", code: Int(EBADMSG), userInfo: [NSLocalizedDescriptionKey: "Risposta NTP non valida"])
                }

                let seconds = UInt32(response[40]) << 24
                    | UInt32(response[41]) << 16
                    | UInt32(response[42]) << 8
                    | UInt32(response[43])
                let fraction = UInt32(response[44]) << 24
                    | UInt32(response[45]) << 16
                    | UInt32(response[46]) << 8
                    | UInt32(response[47])
                let serverTimestamp = TimeInterval(seconds) + TimeInterval(fraction) / 4_294_967_296
                let roundTrip = ProcessInfo.processInfo.systemUptime - requestSentAt
                return Date(timeIntervalSince1970: serverTimestamp - ntpEpochOffset + roundTrip / 2)
            }

            lastSocketError = errno
            address = entry.ai_next
            if address == nil { break }
        }

        throw NSError(domain: NSPOSIXErrorDomain, code: Int(lastSocketError))
    }
}
