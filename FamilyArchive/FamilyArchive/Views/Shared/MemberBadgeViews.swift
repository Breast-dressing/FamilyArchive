import SwiftUI

/// Canonical member badge styling shared by the family detail list and the
/// member detail header. The nameplate color is the required #DEC27B.
struct MemberMedalBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                Color(uiColor: .tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}

struct MemberNameplateLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(
                Color(red: 222 / 255, green: 194 / 255, blue: 123 / 255)
            )
    }
}

struct MemberBadgeRow: View {
    let medalLevel: String
    let nameplate: String

    var body: some View {
        if !medalLevel.isEmpty || !nameplate.isEmpty {
            HStack(spacing: 6) {
                if !medalLevel.isEmpty {
                    MemberMedalBadge(text: medalLevel)
                }
                if !nameplate.isEmpty {
                    MemberNameplateLabel(text: nameplate)
                }
            }
        }
    }
}
