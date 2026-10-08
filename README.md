# NYC Culture

Home-screen web app listing exhibitions and major events at libraries, museums, parks and city sites in Manhattan, Brooklyn and Queens.

- `index.html` – the app (Agenda, Exhibitions, Map, Institutions; All vs Core 30)
- `data.json` – the listings feed, refreshed every Monday by a scheduled scan
- `sw.js`, `manifest.webmanifest`, `icons/` – install and offline support

Install on iPhone: open the site in Safari → Share → Add to Home Screen.

## Native iPhone app (ios/)

SwiftUI app with the same four views, reading the same `data.json`. GitHub Actions compile-checks it on every change and commits the generated `ios/NYCCulture.xcodeproj`.

Install on your iPhone from a Mac:
1. Install Xcode (Mac App Store), then open `ios/NYCCulture.xcodeproj`.
2. Xcode → Settings → Accounts → add your Apple ID.
3. Select the NYCCulture target → Signing & Capabilities → Team: your Personal Team.
4. Connect the iPhone by cable, turn on Developer Mode (Settings → Privacy & Security), pick it as the run destination, press ⌘R.
5. On the iPhone: Settings → General → VPN & Device Management → trust your developer certificate.

With a free Apple ID the install lasts 7 days; run it from Xcode again to renew. A paid Apple Developer account removes the limit.
