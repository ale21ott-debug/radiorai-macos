# Radio Rai for macOS 📻

An elegant native macOS app for discovering Rai Radio stations, seeing what's on air, and listening live.

## Open in Xcode

1. Open `Package.swift` in Xcode.
2. Select the `RadioRai` scheme and a Mac destination.
3. Press **Run**.

The app uses SwiftUI, AVPlayer, and the RaiPlay Sound on-air JSON endpoint. It has no third-party Swift dependencies and targets macOS 14 or later.

## Features

- Browse and search Rai Radio stations with the current program.
- View episode details, descriptions and track lists, plus the next program.
- Listen to live streams using the built-in player.
- Adjust playback volume from the player bar.
- Control playback, station selection, and volume from the macOS menu bar.
- Switch between light and dark appearance; the choice is saved on this Mac.
- See the date in Italian and a seconds clock synchronized with `ntp1.inrim.it`.
- Refresh the live schedule and selected station details automatically at each minute boundary.
- Refresh the on-air schedule with ⌘R.

## Swift package

To build from a terminal with the Swift toolchain:

```bash
swift build
swift run
```

## License

This project is available under the [MIT License](LICENSE).
