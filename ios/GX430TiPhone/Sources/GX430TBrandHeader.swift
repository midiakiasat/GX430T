import SwiftUI

struct GX430TBrandHeader: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 12 : 16) {
            Image("GX430TLogo")
                .resizable()
                .scaledToFit()
                .frame(
                    width: compact ? 46 : 58,
                    height: compact ? 46 : 58
                )
                .accessibilityLabel("GX430T logo")

            VStack(alignment: .leading, spacing: 3) {
                Text("GX430T")
                    .font(
                        compact
                            ? .title2.weight(.black)
                            : .largeTitle.weight(.black)
                    )

                Text("MAC + IPHONE LABEL CONTROL")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(compact ? 14 : 18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
