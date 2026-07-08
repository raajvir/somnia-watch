import SwiftUI

/// ABC Social — the same brand font used by the phone app. Falls back to the
/// system font automatically if a weight fails to load (Font.custom degrades
/// silently rather than crashing), so this is safe even if a file goes missing.
enum SomniaFont {
    static func black(_ size: CGFloat) -> Font {
        .custom("ABCSocialUnlicensedTrial-Black", size: size)
    }
    static func bold(_ size: CGFloat) -> Font {
        .custom("ABCSocialUnlicensedTrial-Bold", size: size)
    }
    static func regular(_ size: CGFloat) -> Font {
        .custom("ABCSocialUnlicensedTrial-Regular", size: size)
    }
    static func light(_ size: CGFloat) -> Font {
        .custom("ABCSocialUnlicensedTrial-Light", size: size)
    }
}
