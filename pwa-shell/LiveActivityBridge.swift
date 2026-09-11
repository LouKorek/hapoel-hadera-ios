import Foundation
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

// Token plumbing for the live-match card. The card itself is started,
// updated and ended by the club's server over APNs; the app only has to
// hand the server the two kinds of tokens ActivityKit issues:
//
//  1. the push-to-start token (one per device, iOS 17.2+), so the server
//     can open the card when line-ups are published;
//  2. the per-activity update token, issued once a card is on screen, so
//     the server can push every goal into it.
//
// iOS launches the app in the background for a push-to-start, which is when
// the update token is observed and reported. Reports go straight to the
// server with URLSession — no web view involved, it may not be loaded.
final class TokenBox: @unchecked Sendable { var value = "" }

enum LiveActivityBridge {
    private static let endpoint = URL(string: "https://hapoelhadera.co.il/api/push/live-activity")!
    private static var started = false
    private static var pendingStartToken: String?
    private static var observedActivities = Set<String>()

    static func start() {
        guard !started else { return }
        started = true
        #if canImport(ActivityKit)
        if #available(iOS 17.2, *) {
            Task {
                for await data in Activity<LiveMatchAttributes>.pushToStartTokenUpdates {
                    let token = data.map { String(format: "%02x", $0) }.joined()
                    pendingStartToken = token
                    flushStartToken()
                }
            }
            Task {
                for activity in Activity<LiveMatchAttributes>.activities { observe(activity) }
                for await activity in Activity<LiveMatchAttributes>.activityUpdates { observe(activity) }
            }
        }
        #endif
    }

    // Called again when the APNs device token arrives: the start token is
    // keyed by device on the server, so both must be known before posting.
    static func deviceTokenChanged() { flushStartToken() }

    private static func flushStartToken() {
        guard let start = pendingStartToken, let device = PushRegistry.deviceToken else { return }
        post(["deviceToken": device, "startToken": start, "lang": Locale.preferredLanguages.first ?? "he"])
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private static func observe(_ activity: Activity<LiveMatchAttributes>) {
        guard !observedActivities.contains(activity.id) else { return }
        observedActivities.insert(activity.id)
        let matchId = activity.attributes.matchId
        let lastToken = TokenBox()
        Task {
            for await data in activity.pushTokenUpdates {
                let token = data.map { String(format: "%02x", $0) }.joined()
                lastToken.value = token
                post(["deviceToken": PushRegistry.deviceToken ?? "", "matchId": matchId, "activityId": activity.id, "activityToken": token])
            }
        }
        Task {
            for await state in activity.activityStateUpdates {
                if state == .dismissed || state == .ended {
                    post(["deviceToken": PushRegistry.deviceToken ?? "", "matchId": matchId, "activityId": activity.id, "activityToken": lastToken.value, "ended": true])
                    observedActivities.remove(activity.id)
                    break
                }
            }
        }
    }
    #endif

    private static func post(_ body: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        URLSession.shared.dataTask(with: req).resume()
    }
}
