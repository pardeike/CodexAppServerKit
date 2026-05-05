#if os(macOS)
import SwiftUI

public struct CodexRateLimitStatusView: View {
    private let rateLimits: CodexRateLimitsReadResult?

    public init(rateLimits: CodexRateLimitsReadResult?) {
        self.rateLimits = rateLimits
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preferred = rateLimits?.preferredBucket {
                bucketView(preferred, prominent: true)

                let secondaryBuckets = rateLimits?.sortedBuckets.filter { $0.id != preferred.id } ?? []
                if !secondaryBuckets.isEmpty {
                    Divider()
                    ForEach(secondaryBuckets) { bucket in
                        bucketView(bucket, prominent: false)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No rate-limit data yet",
                    systemImage: "gauge.with.dots.needle.33percent",
                    description: Text("Refresh after signing in to Codex.")
                )
            }
        }
    }

    private func bucketView(_ bucket: CodexRateLimitBucket, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(bucket.displayName)
                    .font(prominent ? .headline : .subheadline.weight(.semibold))

                if let planType = bucket.planType {
                    Text(planType.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let used = bucket.primary?.usedPercent {
                    Text(used, format: .number.precision(.fractionLength(0))) + Text("%")
                }
            }

            if let primary = bucket.primary {
                Gauge(value: primary.clampedUsedPercent, in: 0...100) {
                    Text("Usage")
                } currentValueLabel: {
                    Text(primary.clampedUsedPercent, format: .number.precision(.fractionLength(0))) + Text("%")
                }
                .gaugeStyle(.accessoryLinearCapacity)

                metadataView(window: primary)
            }

            if let secondary = bucket.secondary {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secondary limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Gauge(value: secondary.clampedUsedPercent, in: 0...100) {
                        Text("Secondary usage")
                    } currentValueLabel: {
                        Text(secondary.clampedUsedPercent, format: .number.precision(.fractionLength(0))) + Text("%")
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    metadataView(window: secondary)
                }
            }

            if let reached = bucket.rateLimitReachedType, !reached.isEmpty {
                Label("Limit state: \(reached)", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func metadataView(window: CodexRateLimitWindow) -> some View {
        HStack(spacing: 12) {
            if let minutes = window.windowDurationMins {
                Label("\(Int(minutes)) min window", systemImage: "clock")
            }

            if let resetDate = window.resetDate {
                Label {
                    Text("Resets ") + Text(resetDate, style: .relative)
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help(resetDate.formatted(date: .abbreviated, time: .standard))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
#endif
