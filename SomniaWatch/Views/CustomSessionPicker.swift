import SwiftUI

/// The custom-length sheet raised from the bottom. The Digital Crown (bound by
/// the parent) scrolls the minute value; on-screen controls cancel or start.
///
/// Note: watchOS reserves the Crown *button* (press / long-press) for the
/// system, so there is no "click crown to confirm" — the blue Go button is the
/// confirm affordance, matching the design.
struct CustomSessionPicker: View {
    @Binding var minutes: Double
    var isFocused: Bool
    let onCancel: () -> Void
    let onGo: () -> Void

    private var value: Int { Int(minutes.rounded()) }

    var body: some View {
        VStack {
            // A hard floor, not just "whatever's left" — on the smaller watch
            // sizes the sheet's fixed content height left almost nothing for
            // this Spacer to distribute, so the sheet crept up flush against
            // the clock. This guarantees clearance on every screen size.
            Spacer(minLength: 34)

            VStack(spacing: 6) {
                (Text("Custom ").font(SomniaFont.regular(12))
                    + Text("Somnia").font(SomniaFont.bold(12))
                    + Text(" session").font(SomniaFont.regular(12)))
                    .foregroundStyle(Color(red: 0.42, green: 0.44, blue: 0.5))
                    .padding(.top, 8)

                HStack(spacing: 10) {
                    circleButton(system: "xmark",
                                 fg: Color(red: 0.42, green: 0.44, blue: 0.5),
                                 bg: Color(red: 0.90, green: 0.91, blue: 0.93),
                                 action: onCancel)

                    numberWheel

                    circleButton(system: "play.fill",
                                 fg: .white,
                                 bg: SomniaColors.accentBright,
                                 action: onGo)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var numberWheel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.86, blue: 0.89), lineWidth: 1.5)

            VStack(spacing: -2) {
                neighbor(value - 1, show: value - 1 >= SessionBounds.minMinutes)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(value)")
                        .font(SomniaFont.black(36))
                        .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.17))
                    Text("min")
                        .font(SomniaFont.regular(11))
                        .foregroundStyle(Color(red: 0.55, green: 0.57, blue: 0.62))
                }
                neighbor(value + 1, show: value + 1 <= SessionBounds.maxMinutes)
            }
            .padding(.vertical, 4)

            // Faint edge fades so neighbors read as "scrolling past".
            VStack {
                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 18)
                Spacer()
                LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                    .frame(height: 18)
            }
            .allowsHitTesting(false)
        }
        .frame(width: 86, height: 84)
        .scaleEffect(isFocused ? 1.0 : 0.97)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private func neighbor(_ n: Int, show: Bool) -> some View {
        Text(show ? "\(n)" : " ")
            .font(SomniaFont.regular(19))
            .foregroundStyle(Color(red: 0.72, green: 0.74, blue: 0.78))
    }

    private func circleButton(system: String, fg: Color, bg: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 44, height: 44)
                .background(Circle().fill(bg))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CustomSessionPicker(
        minutes: .constant(8), isFocused: true,
        onCancel: {}, onGo: {}
    )
    .background(Color.black)
}
