# Scan2WA 📱🔍

A high-performance iOS camera scanner designed for **iPhone 15 Pro Max** and packaged as an `.ipa` for **LiveContainer**, AltStore, and SideStore.

Scan2WA uses on-device Apple Vision OCR to detect phone numbers in real time directly through your camera feed, showing clickable badges over numbers and providing instant actions:
- 🟢 **WA Business**: Direct 1-tap WhatsApp Business chat with the scanned number (auto-applying country prefix)
- 📋 **Copy**: Copies the clean phone number to clipboard with haptic feedback
- 📞 **Call**: Dials the phone number via native phone call prompt

---

## 🌟 iPhone 15 Pro Max Features
- **Triple Camera & Macro Auto-Switching**: Built with `AVCaptureDevice.builtInTripleCamera`. As you bring the phone close to documents, business cards, or screens, iOS automatically engages the Ultra-Wide macro sensor.
- **Dedicated Zoom Presets**: Instant switches for `0.5x` (Macro), `1x` (Main 24mm), `2x` (48mm sensor crop), and `5x` (Tetraprism 120mm telephoto).
- **Interactive Bounding Box Viewfinder**: Detected numbers are highlighted directly in the live camera viewport with glowing badges.
- **Freeze Frame Mode**: Freeze moving or vibrating camera feeds to comfortably tap small numbers.
- **Torch Toggle**: Built-in flashlight toggle for low-light scanning.
- **Default Country Code**: Configurable default prefix (e.g., `+212`, `+1`, `+33`) for local numbers starting with `0`.

---

## 📦 How to Install in LiveContainer

1. Download the `Scan2WA.ipa` from the [Releases](https://github.com/ilyassbourass/Scan2WA/releases) or Artifacts.
2. Open **LiveContainer** on your iPhone 15 Pro Max.
3. Tap the **`+`** icon at the top right of LiveContainer.
4. Select the downloaded `Scan2WA.ipa` from your Files app.
5. Tap **Scan2WA** to launch it.
6. Grant Camera permissions when prompted.

---

## 🛠️ Build and Automation

The repository includes a GitHub Actions workflow (`.github/workflows/build_ipa.yml`) that automatically compiles the Swift project using `xcodegen` and `xcodebuild` on macOS runners, packages the unsigned `.ipa`, and publishes it to GitHub Releases.
