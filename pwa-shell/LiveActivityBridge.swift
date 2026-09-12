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
        // The club crest is the same for every match — have it on disk
        // before the first card ever opens.
        CrestStore.fetch("https://hapoelhadera.co.il/img/logo-512.webp") { _ in }
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
        let report: (Data) -> Void = { data in
            let token = data.map { String(format: "%02x", $0) }.joined()
            guard token != lastToken.value else { return }
            lastToken.value = token
            post(["deviceToken": PushRegistry.deviceToken ?? "", "matchId": matchId, "activityId": activity.id, "activityToken": token])
        }
        // A card started by push already carries its token — the updates
        // sequence does not replay it, so read it first, then follow changes.
        if let current = activity.pushToken { report(current) }
        Task {
            for await data in activity.pushTokenUpdates { report(data) }
        }
        // Crests: fetch both into the shared container, then re-render the
        // card with its current state so the images appear without waiting
        // for the next match event.
        let logos = [activity.attributes.homeLogo, activity.attributes.awayLogo].filter { !$0.isEmpty }
        let missing = logos.filter { !CrestStore.has($0) }
        if !missing.isEmpty {
            let pending = TokenBox(); pending.value = String(missing.count)
            for url in missing {
                CrestStore.fetch(url) { _ in
                    let left = (Int(pending.value) ?? 1) - 1
                    pending.value = String(left)
                    if left <= 0 {
                        Task { await activity.update(ActivityContent(state: activity.content.state, staleDate: nil)) }
                    }
                }
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

    // The report often goes out from a background launch (a push-to-start
    // woke the app); a background task keeps the process alive until the
    // request has completed instead of letting iOS suspend it mid-flight.
    private static func post(_ body: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        DispatchQueue.main.async {
            var bg = UIBackgroundTaskIdentifier.invalid
            bg = UIApplication.shared.beginBackgroundTask(withName: "live-activity-token") {
                UIApplication.shared.endBackgroundTask(bg); bg = .invalid
            }
            URLSession.shared.dataTask(with: req) { _, _, _ in
                DispatchQueue.main.async {
                    if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
                }
            }.resume()
        }
    }
}
