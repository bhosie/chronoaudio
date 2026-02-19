# GuitarApp

A native macOS app for learning and playing along with songs on guitar or other instruments. Import any audio file, slow it down without changing pitch, loop the tricky sections, and stay in time with a built-in click track.

## Features

- **Audio import** — Open MP3, AAC, WAV, and AIFF files
- **Time-stretch playback** — Slow audio down to 25%–100% speed with no pitch change
- **Loop regions** — Set in/out markers on the waveform and loop any section seamlessly. Loop markers stay anchored to the audio timeline — they don't drift when you change playback speed
- **Waveform display** — Scrolling waveform with a live playhead and draggable loop markers
- **Click track** — Built-in metronome with auto BPM detection and manual override

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (for building from source)

## Building from Source

```bash
git clone <repo-url>
cd guitar_app
swift build
```

To run:

```bash
swift run
```

To run tests:

```bash
swift test
```

## Running the App Without Xcode (Pre-built)

Because this app is distributed without code signing, macOS Gatekeeper will block it on first launch. To open it:

1. Right-click the app and choose **Open**
2. Click **Open** in the dialog that appears

Or go to **System Settings → Privacy & Security** and click **Open Anyway** after the first blocked launch attempt.

## Project Structure

```
Sources/GuitarApp/
├── App/                    # App entry point and menu bar commands
├── Audio/                  # AVAudioEngine graph, file loading, loop and time-stretch control
├── BeatDetection/          # FFT-based BPM detection using Accelerate/vDSP
├── Models/                 # Value types: AudioTrack, LoopRegion, PlaybackState, MetronomeConfig
├── ViewModels/             # ObservableObject ViewModels (all @MainActor)
├── Views/                  # SwiftUI views
├── Waveform/               # Waveform sampling and rendering
└── Utilities/              # Time formatting helpers

Tests/GuitarAppTests/
├── Fixtures/               # TestAudioGenerator for synthetic test audio
└── *Tests.swift            # XCTest unit tests per module
```

## Architecture

The app uses MVVM with SwiftUI. Audio processing runs on background threads via AVAudioEngine; ViewModels are `@MainActor`-isolated and observe state changes via `@Published` properties.

```
SwiftUI Views
    ↓  @StateObject / @ObservedObject
ViewModels  (@MainActor, ObservableObject)
    ↓  method calls / async callbacks
Audio Services  (AVAudioEngine, AVAudioPlayerNode, AVAudioUnitTimePitch)
    ↓
Apple Frameworks  (AVFoundation, Accelerate)
```

## Tech Stack

- **Swift + SwiftUI** — native macOS UI
- **AVFoundation / AVAudioEngine** — audio playback and processing
- **AVAudioUnitTimePitch** — time-stretching without pitch change
- **Accelerate / vDSP** — FFT-based waveform sampling and BPM detection
- **XCTest** — unit testing

## Implementation Status

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Project scaffold | ✅ Done |
| 1 | Audio engine core (import, playback, time-stretch) | ✅ Done |
| 2 | Loop region engine | 🔲 Pending |
| 3 | Waveform display | 🔲 Pending |
| 4 | Metronome & BPM detection | 🔲 Pending |
| 5 | UI integration & polish | 🔲 Pending |

## Distribution

This app is distributed as an unsigned binary (no Apple Developer Program membership required). See the Gatekeeper instructions above for first-launch setup.
