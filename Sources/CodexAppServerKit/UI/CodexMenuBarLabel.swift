#if os(macOS)
import SwiftUI

public struct CodexMenuBarLabel: View {
    @ObservedObject private var controller: CodexRateLimitController

    public init(controller: CodexRateLimitController) {
        self.controller = controller
    }

    public var body: some View {
        Label {
            if let percent = controller.rateLimits?.preferredBucket?.primary?.usedPercent {
                Text("Codex \(Int(percent.rounded()))%")
            } else if controller.state == .signingIn {
                Text("Codex…")
            } else {
                Text("Codex")
            }
        } icon: {
            Image(systemName: symbolName)
        }
    }

    private var symbolName: String {
        switch controller.state {
        case .failed:
            return "exclamationmark.triangle"
        case .needsSignIn, .signingIn:
            return "person.crop.circle.badge.questionmark"
        case .ready:
            return "gauge.with.dots.needle.50percent"
        case .idle, .starting:
            return "hourglass"
        }
    }
}
#endif
