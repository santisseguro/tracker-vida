# Tracker Vida

Private personal iPhone app for life organization, now built as a native iOS SwiftUI project.

## Current Status

The project contains a native SwiftUI foundation only:

- SwiftUI app shell with tabs for Dashboard, Gym / Health, University, Money, and Settings.
- Swift domain models for the v1 product areas.
- Static mock data for visual development.
- Reusable SwiftUI presentation components.

Supabase, real AI calls, HealthKit, persistence, and create/edit/delete workflows are intentionally not implemented yet.

## Open In Xcode

Open the project:

```bash
open TrackerVida.xcodeproj
```

Then in Xcode:

1. Select the `TrackerVida` scheme.
2. Select an iPhone simulator or a connected iPhone.
3. Press `Run`.

## Command-Line Build

When full Xcode is installed and selected:

```bash
xcodebuild -project TrackerVida.xcodeproj -scheme TrackerVida -destination 'platform=iOS Simulator,name=iPhone 16' build
```

If `xcodebuild` reports that Command Line Tools are active, select full Xcode first:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
