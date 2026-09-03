import Foundation
import UIKit
import WebKit
import UserNotifications

// Remote push without Firebase. The site asks for permission through the
// existing bridge; on grant the app registers with APNs and hands the device
// token back to the page as a 'push-token' DOM event. The page posts it to
// /api/push/subscribe, and from then on the club's own server talks to APNs
// directly. No third-party SDK, no tracking, nothing to keep updated.

private var pendingTokenRequest = false

func handleSubscribeTouch(message: WKScriptMessage) {
    // Topic subscriptions were an FCM concept; the server targets by audience.
    returnPermissionResult(isGranted: false)
}

func handlePushPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        DispatchQueue.main.async {
            if granted {
                pendingTokenRequest = true
                UIApplication.shared.registerForRemoteNotifications()
            }
            returnPermissionResult(isGranted: granted)
        }
    }
}

func handlePushState() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        var state = "default"
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: state = "granted"
        case .denied: state = "denied"
        case .notDetermined: state = "default"
        @unknown default: state = "default"
        }
        DispatchQueue.main.async {
            returnPermissionState(state: state)
        }
    }
}

// The page asks for the token explicitly after permission is granted. If the
// token is already known it is returned at once; otherwise APNs registration
// is (re)triggered and the token is delivered when it arrives.
func handleFCMToken() {
    if let token = PushRegistry.deviceToken {
        checkViewAndEvaluate(event: "push-token", detail: "'\(token)'")
    } else {
        pendingTokenRequest = true
        UIApplication.shared.registerForRemoteNotifications()
    }
}

enum PushRegistry {
    static var deviceToken: String?

    static func didRegister(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        if pendingTokenRequest {
            pendingTokenRequest = false
            checkViewAndEvaluate(event: "push-token", detail: "'\(token)'")
        }
    }

    static func didFail(_ error: Error) {
        pendingTokenRequest = false
        checkViewAndEvaluate(event: "push-token", detail: "null")
    }
}

func returnPermissionResult(isGranted: Bool) {
    if isGranted {
        checkViewAndEvaluate(event: "push-permission-request", detail: "'granted'")
    } else {
        checkViewAndEvaluate(event: "push-permission-request", detail: "'denied'")
    }
}

func returnPermissionState(state: String) {
    checkViewAndEvaluate(event: "push-permission-state", detail: "'\(state)'")
}

func checkViewAndEvaluate(event: String, detail: String) {
    if (!PWAShell.webView.isHidden && !PWAShell.webView.isLoading) {
        DispatchQueue.main.async(execute: {
            PWAShell.webView.evaluateJavaScript("this.dispatchEvent(new CustomEvent('\(event)', { detail: \(detail) }))")
        })
    } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkViewAndEvaluate(event: event, detail: detail)
        }
    }
}
