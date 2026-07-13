import SwiftUI

/// Landing screen. A prominent "Start Sleep" button begins a default session;
/// rotating the Digital Crown raises a custom-length picker from below.
struct HomeView: View {
    var startWithPicker: Bool = false
    /// (minutes, dynamic) — dynamic is true only for the quick-start button.
    let onStart: (Int, Bool) -> Void
    let onHistory: () -> Void
    /// Long-press the history button — a diagnostics screen doesn't need its
    /// own permanent icon competing for the same tight corner.
    var onLiveData: (() -> Void)? = nil

    /// The greeting name will eventually come from the paired phone's profile;
    /// hardcoded for now on the standalone build.
    private let name = "Raaj"

    private enum Focusable { case home, picker }
    @FocusState private var focus: Focusable?

    @State private var showPicker = false
    @State private var homeCrown = 0.0
    @State private var minutes = Double(SessionBounds.defaultMinutes)

    var body: some View {
        ZStack {
            background

            VStack {
                ZStack(alignment: .top) {
                    // Top-aligned (not centered) so the logo and the history
                    // button can each control their own offset independently
                    // — padding one no longer nudges the other.
                    HStack {
                        Spacer(minLength: 0)
                        Image("Wordmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 74)
                            .opacity(0.85)
                        // Asymmetric — reserves room for the system clock on
                        // the right, which a plain centered logo doesn't
                        // know about. On the narrowest screens (SE 40mm) a
                        // true center placed the logo's edge right under the
                        // clock digits, overlapping them.
                        Spacer(minLength: 54)
                    }
                    HStack {
                        historyButton
                            // Only this element gets extra top clearance —
                            // it sits both top- and side-flush at once, so
                            // the rounded corner clips it before the logo,
                            // which stays centered and clear of the curve.
                            // Ultra's corner curvature needed a touch more
                            // than the other models did.
                            .padding(.top, 14)
                            .padding(.leading, 8)
                        Spacer()
                    }
                }
                .opacity(showPicker ? 0.3 : 1)

                Spacer(minLength: 0)

                GreetingText(name: name)
                    .padding(.horizontal, 10)
                    // In the picker state the greeting rides up out of the way
                    // and fades out so the sheet's top edge doesn't slice it
                    // mid-glyph on the narrower watch sizes.
                    .offset(y: showPicker ? -18 : 0)
                    .opacity(showPicker ? 0 : 1)

                if !showPicker {
                    startButton
                        .transition(.opacity)
                }

                Spacer(minLength: 10)

                if !showPicker {
                    floorHint
                        .transition(.opacity)
                }
            }
            // Applied to the whole stack, not just the header row — a child's
            // own ignoresSafeArea doesn't pull it above the parent's normal
            // safe-area-constrained starting position; the parent has to
            // opt out too, or the fix silently does nothing.
            .ignoresSafeArea(edges: .top)

            // Crown surface for the home state: any rotation raises the picker.
            .focusable(!showPicker)
            .focused($focus, equals: .home)
            .digitalCrownRotation(
                $homeCrown,
                from: 0, through: 1000, by: 1,
                sensitivity: .low, isContinuous: true,
                isHapticFeedbackEnabled: false
            )
            .onChange(of: homeCrown) { _, _ in
                if !showPicker { openPicker() }
            }

            if showPicker {
                CustomSessionPicker(
                    minutes: $minutes,
                    isFocused: focus == .picker,
                    onCancel: closePicker,
                    onGo: { onStart(Int(minutes), false) }
                )
                .focusable(true)
                .focused($focus, equals: .picker)
                .digitalCrownRotation(
                    $minutes,
                    from: Double(SessionBounds.minMinutes),
                    through: Double(SessionBounds.maxMinutes),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showPicker)
        .onAppear {
            if startWithPicker {
                showPicker = true
                focus = .picker
            } else {
                focus = .home
            }
        }
    }

    private var background: some View {
        ZStack {
            SomniaColors.background.ignoresSafeArea()
            // Soft blue glow rising behind the primary button.
            RadialGradient(
                colors: [SomniaColors.accentBright.opacity(0.55), .clear],
                center: .center, startRadius: 2, endRadius: 130
            )
            .offset(y: 6)
            .ignoresSafeArea()
            Sparkles()
        }
    }

    private var historyButton: some View {
        Button(action: onHistory) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 28, height: 28)
                .background(Circle().fill(.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                onLiveData?()
            }
        )
    }

    private var startButton: some View {
        Button {
            onStart(SessionBounds.defaultMinutes, true)
        } label: {
            VStack(spacing: 2) {
                Text("Start Sleep")
                    .font(SomniaFont.black(23))
                    .foregroundStyle(Color(red: 0.16, green: 0.17, blue: 0.22))
                Text("About \(SessionBounds.defaultMinutes) minutes — adapts to your breathing")
                    .font(SomniaFont.regular(10))
                    .foregroundStyle(Color(red: 0.42, green: 0.44, blue: 0.5))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    /// The custom-length hint. No background — a watch screen's bottom edge
    /// is physically rounded by the hardware, so a pill or bar here always
    /// shows a sliver of black in the corners that we can't paint over.
    /// Freestanding text sidesteps the mismatch entirely.
    private var floorHint: some View {
        Text("Use crown to choose a custom length")
            .font(SomniaFont.regular(10.5))
            .foregroundStyle(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.bottom, 2)
            .ignoresSafeArea(edges: .bottom)
    }

    private func openPicker() {
        minutes = Double(SessionBounds.defaultMinutes)
        showPicker = true
        focus = .picker
    }

    private func closePicker() {
        showPicker = false
        focus = .home
        // Deliberately NOT resetting homeCrown here: doing so changes its
        // value, which re-fires the onChange below and immediately reopens
        // the picker it was just told to close. The crown value doesn't need
        // to be zero — any further rotation still produces a fresh delta.
    }
}

/// Time-of-day greeting with an emphasized name.
struct GreetingText: View {
    let name: String

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        case 17..<22: return "Good Evening,"
        default: return "Good Night,"
        }
    }

    var body: some View {
        (Text(greeting + " ").font(SomniaFont.regular(17))
            + Text(name).font(SomniaFont.bold(17)))
            .foregroundStyle(SomniaColors.text)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }
}

/// A few faint twinkling accents scattered on the backdrop.
private struct Sparkles: View {
    private let dots: [CGPoint] = [
        CGPoint(x: 0.22, y: 0.30), CGPoint(x: 0.80, y: 0.24),
        CGPoint(x: 0.86, y: 0.60), CGPoint(x: 0.16, y: 0.66),
        CGPoint(x: 0.70, y: 0.78),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(dots.enumerated()), id: \.offset) { _, p in
                Image(systemName: "sparkle")
                    .font(.system(size: 7))
                    .foregroundStyle(SomniaColors.accent.opacity(0.7))
                    .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    HomeView(onStart: { _, _ in }, onHistory: {})
}
