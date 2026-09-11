import Foundation
#if canImport(ActivityKit)
import ActivityKit

// The live-match card on the Lock Screen and in the Dynamic Island.
// Shared by the app (token plumbing) and the widget extension (the views).
// Everything here is delivered by the club's server over APNs: the static
// attributes arrive with the push-to-start, the content state with every
// update. Field names are the JSON keys in the push payload — keep them in
// sync with netlify/functions/_live.mjs.
@available(iOS 16.2, *)
struct LiveMatchAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var homeScore: Int
        var awayScore: Int
        var minute: String      // "67'" or "" (pre-match, half-time, full-time)
        var status: String      // localised: "בעיצומו" / "מחצית" / "סיום" …
        var lastEvent: String   // localised one-liner: "⚽ 67' אלמוג ימהרן"
        var live: Bool          // false once the match has ended
    }

    var matchId: String
    var homeName: String
    var awayName: String
    var ourSide: String         // "home" | "away"
    var comp: String            // localised competition label
    var url: String             // deep link opened on tap
}
#endif
