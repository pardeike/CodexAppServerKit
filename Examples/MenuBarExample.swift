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
