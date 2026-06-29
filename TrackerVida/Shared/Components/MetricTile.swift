import SwiftUI

struct MetricTile: View {
    var title: String
    var value: String
    var detail: String
    var tint: Color
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
