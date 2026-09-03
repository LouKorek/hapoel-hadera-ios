import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // If the user already granted notifications on an earlier launch,
        // refresh the APNs token silently so a reinstall or token rotation
        // never leaves the device subscribed under a dead token.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async { application.registerForRemoteNotifications() }
            }
        }
        return true
    }

    // MARK: APNs registration

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistry.didRegister(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushRegistry.didFail(error)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Show the banner even while the app is in the foreground — a goal is
    // worth a banner on top of the live page too.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([[.banner, .badge, .sound]])
    }

    // Tapping the notification opens the page the server named in the
    // payload ("url"), defaulting to the live-match page.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let target = (info["url"] as? String) ?? "https://hapoelhadera.co.il/live"
        if let url = URL(string: target), url.host?.hasSuffix("hapoelhadera.co.il") == true {
            DispatchQueue.main.async {
                PWAShell.webView.load(URLRequest(url: url))
            }
        }
        completionHandler()
    }
}
