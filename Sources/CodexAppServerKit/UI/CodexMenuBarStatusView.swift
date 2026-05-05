#if os(macOS)
import SwiftUI

public struct CodexMenuBarStatusView: View {
    @ObservedObject private var controller: CodexRateLimitController
    @Environment(\.openURL) private var openURL

    public init(controller: CodexRateLimitController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch controller.state {
            case .idle, .starting:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Starting Codex…")
                }

            case .needsSignIn, .signingIn, .failed:
                CodexSignInView(controller: controller)
                    .padding(-20)

            case .ready:
                if let account = controller.account {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.email ?? "Codex")
                            .font(.headline)
                            .lineLimit(1)
                        if let planType = account.planType {
                            Text(planType.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                CodexRateLimitStatusView(rateLimits: controller.rateLimits)

                Divider()

                HStack {
                    Button {
                        controller.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Spacer()

                    Button("Sign out") {
                        controller.logout()
                    }
                }

                if let message = controller.lastErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 320, idealWidth: 360, alignment: .leading)
        .task {
            await controller.connect()
        }
    }
}
#endif
