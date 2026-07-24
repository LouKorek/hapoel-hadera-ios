import Foundation
import UIKit
import WebKit
import UserNotifications

// Firebase-free stubs: the web bridge message handlers stay functional,
// local notification permission works, remote push (FCM) is disabled.

func handleSubscribeTouch(message: WKScriptMessage) {
    // Remote push topics are not supported in this build.
    returnPermissionResult(isGranted: false)
}

func handlePushPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        DispatchQueue.main.async {
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

func handleFCMToken() {
    checkViewAndEvaluate(event: "push-token", detail: "null")
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
