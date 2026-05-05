# CodexAppServerKit

A Swift 6 / macOS 15 package for embedding Codex account sign-in and ChatGPT Codex rate-limit display in a sandboxed Mac app.

The package implements **Mode B** from the discussion:

```text
Your sandboxed Mac app
  └─ bundled, signed `codex app-server` helper over stdio / JSONL
       └─ ChatGPT sign-in managed by Codex
       └─ account/rateLimits/read
```

It uses the documented Codex app-server JSON-RPC surface:

- `initialize` + `initialized`
- `account/read`
- `account/login/start` with `chatgpt` and `chatgptDeviceCode`
- `account/login/completed` notifications
- `account/updated` notifications
- `account/rateLimits/read`
- `account/rateLimits/updated` notifications
- `account/logout`

OpenAI docs: <https://developers.openai.com/codex/app-server>

## What is included

- `CodexAppServerConnection`: low-level JSON-RPC over stdio.
- `CodexAppServerClient`: typed account, login, logout, and rate-limit methods.
- `CodexRateLimitController`: `@MainActor` `ObservableObject` for SwiftUI.
- `CodexSignInView`: full sign-in UI with browser and device-code flows.
- `CodexRateLimitStatusView`: gauges and reset/window display.
- `CodexMenuBarStatusView`: drop-in menu-bar popover/menu content.
- `CodexMenuBarLabel`: compact `MenuBarExtra` label.

## What is intentionally not included

This package does **not** include the Codex executable. You need to bundle and sign a `codex` executable with your app, then pass its URL into the package.

That is deliberate:

- SwiftPM packages should not pretend to ship or sign third-party executables for the host app.
- Mac App Store review/signing/entitlements must be handled by the final app bundle.
- The bundled helper should run inside your app sandbox and use an app-container-local `CODEX_HOME`.

## Package setup

```swift
// Package.swift of your app/package
.package(path: "../CodexAppServerKit")
```

or add the package folder in Xcode via **File → Add Package Dependencies…**.

## Minimal menu-bar usage

```swift
import CodexAppServerKit
import SwiftUI

@main
struct LimitMenuApp: App {
    @StateObject private var codex = CodexRateLimitController(
        configuration: try! .init(
            executableURL: CodexAppServerConfiguration.bundledExecutable(named: "codex"),
            clientInfo: .init(
                name: "limit_menu",
                title: "Limit Menu",
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
        )
    )

    var body: some Scene {
        MenuBarExtra {
            CodexMenuBarStatusView(controller: codex)
        } label: {
            CodexMenuBarLabel(controller: codex)
        }
    }
}
```

## Window-based sign-in usage

```swift
import CodexAppServerKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var codex: CodexRateLimitController

    init() {
        let executable = try! CodexAppServerConfiguration.bundledExecutable(named: "codex")
        _codex = StateObject(wrappedValue: CodexRateLimitController(
            configuration: .init(
                executableURL: executable,
                clientInfo: .init(name: "my_app", title: "My App", version: "1.0")
            )
        ))
    }

    var body: some View {
        CodexSignInView(controller: codex)
    }
}
```

## Bundling the `codex` helper

One practical host-app setup:

1. Add the `codex` executable to your Xcode project.
2. Add a **Copy Files** phase for the app target.
3. Destination: **Executables** or **Resources/Helpers**.
4. Ensure the copied executable keeps its executable bit.
5. Sign it as part of the final app bundle.
6. Give the helper sandbox inheritance entitlements.

For an inherited sandbox helper, use entitlements like:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.inherit</key>
    <true/>
</dict>
</plist>
```

Your host app needs at least:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

For the browser OAuth callback flow, you may also need:

```xml
<key>com.apple.security.network.server</key>
<true/>
```

The device-code flow is the recommended default for App Store builds because it does not depend on a localhost callback listener.

## Sandboxed Codex home

By default, the package sets:

```text
CODEX_HOME=<Application Support>/<bundle id>/CodexHome
```

In a sandboxed app, that resolves inside the app container. That keeps this mode separate from the user's existing `~/.codex` state and avoids scraping the CLI's files.

You can override it:

```swift
let config = CodexAppServerConfiguration(
    executableURL: helperURL,
    codexHomeDirectory: myCodexHomeURL,
    clientInfo: .init(name: "my_app", title: "My App", version: "1.0")
)
```

## Device-code-first sign-in

The UI offers both flows, but `CodexSignInView` presents device-code sign-in first.

Device code flow:

1. The package calls `account/login/start` with `{ "type": "chatgptDeviceCode" }`.
2. Codex returns `verificationUrl`, `userCode`, and `loginId`.
3. The view shows the code, copy button, and sign-in page button.
4. The app waits for `account/login/completed`.
5. The controller refreshes `account/read` and `account/rateLimits/read`.

Browser flow:

1. The package calls `account/login/start` with `{ "type": "chatgpt" }`.
2. Codex returns `authUrl`.
3. The view opens the URL.
4. Codex hosts the local callback and emits completion notifications.

## Notes for App Store review

A concise review note could be:

> The app embeds a signed sandbox-inheriting Codex helper and communicates with it over stdio using Codex's documented app-server protocol. The helper stores its Codex state inside the app container via `CODEX_HOME`. The app uses device-code sign-in by default and reads ChatGPT Codex rate-limit status through `account/rateLimits/read`.

## Current caveats

- This package only wraps account and rate-limit APIs. It deliberately does not expose thread/turn APIs or command execution UI.
- It returns `Method not found` for unexpected server-initiated JSON-RPC requests. That is fine for account/rate-limit usage, but extend `CodexAppServerConnection` if you later drive full Codex threads, approvals, or tools.
- It has Linux-buildable core tests, but the SwiftUI/AppKit views are macOS-only and wrapped in `#if os(macOS)`.
