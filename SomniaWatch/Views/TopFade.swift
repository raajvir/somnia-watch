import SwiftUI

/// A fixed black-to-transparent scrim pinned under the system clock, so
/// scrolled content fades out before it reaches the time instead of visually
/// colliding with it. Doesn't scroll with the content — apply as an overlay
/// on top of a ScrollView, not inside it.
struct TopFade: View {
    var height: CGFloat = 46

    var body: some View {
        LinearGradient(
            colors: [SomniaColors.background, SomniaColors.background.opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: height)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}
