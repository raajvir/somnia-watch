import SwiftUI

/// Minimal iOS host for the Somnia watch app. The product lives on the
/// watch; this screen just explains that and points at the Watch app.
/// (It also gives the future phone companion — live sensor streaming —
/// a place to grow into.)
@main
struct SomniaPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            HostScreen()
        }
    }
}

struct HostScreen: View {
    private let background = Color(red: 0.03, green: 0.04, blue: 0.09)
    private let accent = Color(red: 0.36, green: 0.44, blue: 0.95)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "applewatch")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(accent)

                Text("Somnia lives on your Apple Watch")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Open the Watch app on this iPhone to install Somnia on your watch, then start a wind-down session from your wrist.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                Spacer()

                Text("Guided breathing for sleep — no account, no network, works offline.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    HostScreen()
}
