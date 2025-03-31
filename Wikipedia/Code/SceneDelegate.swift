import UIKit
import BackgroundTasks
import CocoaLumberjackSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
#if TEST
// Avoids loading needless dependencies during unit tests
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }
    
#else

    var window: UIWindow?
    private var appNeedsResume = true

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        guard let appViewController else {
            return
        }
        
        // scene(_ scene: UIScene, continue userActivity: NSUserActivity) and
        // scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
        // windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void)
        // are not called upon terminated state, so we need to handle them explicitly here.
        if let userActivity = connectionOptions.userActivities.first {
            processUserActivity(userActivity)
        } else if !connectionOptions.urlContexts.isEmpty {
            openURLContexts(connectionOptions.urlContexts)
        } else if let shortcutItem = connectionOptions.shortcutItem {
            processShortcutItem(shortcutItem)
        }
        
        UNUserNotificationCenter.current().delegate = appViewController
        appViewController.launchApp(in: window, waitToResumeApp: appNeedsResume)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {

    }

    func sceneDidBecomeActive(_ scene: UIScene) {

        resumeAppIfNecessary()
    }

    func sceneWillResignActive(_ scene: UIScene) {

        UserDefaults.standard.wmf_setAppResignActiveDate(Date())
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        appDelegate?.cancelPendingBackgroundTasks()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {

        appDelegate?.updateDynamicIconShortcutItems()
        appDelegate?.scheduleBackgroundAppRefreshTask()
        appDelegate?.scheduleDatabaseHousekeeperTask()
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        processShortcutItem(shortcutItem, completionHandler: completionHandler)
    }
    
    private func processShortcutItem(_ shortcutItem: UIApplicationShortcutItem, completionHandler: ((Bool) -> Void)? = nil) {
        appViewController?.processShortcutItem(shortcutItem) { handled in
            completionHandler?(handled)
        }
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        processUserActivity(userActivity)
    }
    
    private func processUserActivity(_ userActivity: NSUserActivity) {
        guard let appViewController else {
            return
        }
    
        // Special handling for search from App Intent
        if userActivity.activityType == "org.wikimedia.wikipedia.search",
           let searchTerm = userActivity.userInfo?["WMFSearchTerm"] as? String {
            appViewController.selectedIndex = 4 
            if let searchViewController = appViewController.searchForAppIntents() as? SearchViewController {
                searchViewController.searchTerm = searchTerm

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchViewController.search()
                }
                if appNeedsResume {
                    resumeAppIfNecessary()
                }
                return
            }
        }
        
        // Default handling for other activities
        appViewController.showSplashView()
        var userInfo = userActivity.userInfo
        userInfo?[WMFRoutingUserInfoKeys.source] = WMFRoutingUserInfoSourceValue.deepLinkRawValue
        userActivity.userInfo = userInfo
        
        _ = appViewController.processUserActivity(userActivity, animated: false) { [weak self] in

            guard let self else {
                return
            }
            
            if appNeedsResume {
                resumeAppIfNecessary()
            } else {
                appViewController.hideSplashView()
            }
        }
    }
    
    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: any Error) {
        DDLogDebug("didFailToContinueUserActivityWithType: \(userActivityType) error: \(error)")
    }
    
    func scene(_ scene: UIScene, didUpdate userActivity: NSUserActivity) {
        DDLogDebug("didUpdateUserActivity: \(userActivity)")
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        openURLContexts(URLContexts)
    }
    
    private func openURLContexts(_ URLContexts: Set<UIOpenURLContext>) {
        guard let appViewController else {
            return
        }
        
        guard let firstURL = URLContexts.first?.url else {
            return
        }
        
        if firstURL.host?.contains("wikipedia.org") == true && firstURL.path.contains("/wiki/Special:Search") {
            if let components = URLComponents(url: firstURL, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let term = queryItems.first(where: { $0.name == "search" })?.value {
                appViewController.selectedIndex = 4
            
                if let searchViewController = appViewController.searchForAppIntents() as? SearchViewController {
                    // Initiate search
                    searchViewController.searchTerm = term
                    searchViewController.search()
                  }
//                } else {
//                    print("Wikipedia Web Search: Failed to get SearchViewController")
//                }
                return
            }
        }
        // Handle search intent URL
        if firstURL.scheme == "wikipedia" && firstURL.host == "search" {
            if let components = URLComponents(url: firstURL, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let term = queryItems.first(where: { $0.name == "term" })?.value {
                
                appViewController.selectedIndex = 4
            
                if let searchViewController = appViewController.searchForAppIntents() as? SearchViewController {
                    searchViewController.searchTerm = term
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        searchViewController.search()
                    }
                    
                    if appNeedsResume {
                        resumeAppIfNecessary()
                    }
                } else {
                    print("Wikipedia App Intent: Failed to get SearchViewController")
                    let userActivity = NSUserActivity(activityType: "org.wikimedia.wikipedia.search")
                    userActivity.userInfo = ["WMFSearchTerm": term]
                    appViewController.processUserActivity(userActivity, animated: false) { [weak self] in
                        if self?.appNeedsResume ?? false {
                            self?.resumeAppIfNecessary()
                        }
                    }
                }
                return
            } else {
                print("Wikipedia App Intent: Failed to extract search term from URL: \(firstURL)")
            }
        }
        
        guard let activity = NSUserActivity.wmf_activity(forWikipediaScheme: firstURL) ?? NSUserActivity.wmf_activity(for: firstURL) else {
            resumeAppIfNecessary()
            return
        }
        
        appViewController.showSplashView()
        _ = appViewController.processUserActivity(activity, animated: false) { [weak self] in
            
            guard let self else {
                return
            }
            
            if appNeedsResume {
                resumeAppIfNecessary()
            } else {
                appViewController.hideSplashView()
            }
        }
    }

    // MARK: Private
    
    private var appDelegate: AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }
    
    private var appViewController: WMFAppViewController? {
        return appDelegate?.appViewController
    }
    
    private func resumeAppIfNecessary() {
        if appNeedsResume {
            appViewController?.hideSplashScreenAndResumeApp()
            appNeedsResume = false
        }
    }
    
#endif
}
