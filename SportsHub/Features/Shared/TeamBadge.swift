import SwiftUI

struct TeamBadge: View {
    let team: Team
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: team.colorHex).gradient)
            Text(team.monogram)
                .font(.system(size: size * 0.28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.65)
        }
        .frame(width: size, height: size)
        .overlay {
            Circle().stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

