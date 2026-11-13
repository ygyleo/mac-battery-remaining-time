# Battery Time

The user requested a minimal native macOS app, for Apple Silicon only, showing battery time and a native-style battery icon in the menu bar. The pop-up has two data rows: remaining battery charge and remaining time. Settings have exactly two options: Chinese/English and launch at login. The user also authorized a public repository on their GitHub account, a restrained logo and a DMG release.

Implementation choices: macOS 13+, Swift, AppKit status item/native menu, SwiftUI settings, public IOKit power-source APIs and SMAppService. This keeps the app dependency-free and uses the system's estimates and controls. A web wrapper would add unnecessary size; a fully custom popover would work against the requested native UI.

Defaults: follow preferred system Chinese/English language, login launch off, ordinary charge monochrome, <=20% yellow, <=10% red; plugged in shows a plug. On AC, show time to full when available, otherwise charging/full/connected status. Unavailable estimates are labeled honestly. No battery on desktops shows unavailable.

Use the name Battery Time and MIT license. API keys remain ignored local files. Produce an arm64 application and compressed drag-to-Applications DMG. If no Developer ID identity is available, disclose ad hoc signing and lack of notarization in the release.
