# Grain iOS Food Wallet Starter

This doc-only starter mirrors the Android Food Wallet boundary without touching `sdk/swift` or the existing `templates/ios-starter` package.

The iOS app should own:

- camera/photo capture and any local image lifecycle;
- SwiftUI/UIKit state, notifications, and accessibility;
- protected storage policy;
- accounts or sign-in, if the app has them.

The Grain-owned surface should stay equivalent to the Kotlin `dev.grain.food` facade:

- trust status;
- Food Profile source class: `attested`, `measured`, or `estimated`;
- estimate;
- draft;
- confirmed entry;
- daily totals;
- safe summary.

The safe summary is the UI/logging boundary. It should not contain raw photos, snapshots, trust public keys, private keys, backend account identifiers, or app session state.

For now, use the Kotlin starter as the executable parity reference:

```bash
sdk/kotlin/gradlew -p templates/android-food-wallet-starter check
```
