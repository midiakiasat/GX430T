import SwiftUI

struct GX430TBrandHeader: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 12 : 14) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 14 : 17, style: .continuous)
                    .fill(.primary.opacity(0.06))

                Image("GX430TLogo")
                    .resizable()
                    .scaledToFit()
                    .padding(compact ? 8 : 10)
            }
            .frame(
                width: compact ? 46 : 54,
                height: compact ? 46 : 54
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("GX430T")
                    .font(
                        compact
                            ? .title3.weight(.black)
                            : .title2.weight(.black)
                    )

                Text("PRIVATE LABEL CONTROL")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, compact ? 2 : 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GX430T private label control")
    }
}
