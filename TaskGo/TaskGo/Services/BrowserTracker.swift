import Foundation
import AppKit

struct BrowserURLInfo {
    let url: String
    let domain: String
    let pageTitle: String
}

class BrowserTracker {
    static let shared = BrowserTracker()

    private static let browserBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
        "company.thebrowser.Browser"
    ]

    private static let chromiumBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
        "company.thebrowser.Browser"
    ]

    private var failedBrowsers: Set<String> = []
    private let prefs: TrackingPreferences

    private init() {
        prefs = TrackingPreferences.load()
    }

    static func isBrowser(bundleID: String) -> Bool {
        browserBundleIDs.contains(bundleID)
    }

    func getCurrentURL(for bundleID: String, appName: String) -> BrowserURLInfo? {
        if failedBrowsers.contains(bundleID) {
            return nil
        }

        if bundleID.contains("Safari") {
            return querySafari()
        } else if Self.chromiumBundleIDs.contains(bundleID) {
            return queryChromium(appName: appName)
        } else if bundleID.contains("firefox") {
            return nil
        }

        return nil
    }

    // MARK: - Safari

    private func querySafari() -> BrowserURLInfo? {
        let script = """
        tell application "Safari"
            if (count of windows) = 0 then return ""
            set tabURL to URL of current tab of front window
            set tabName to name of current tab of front window
            return tabURL & "|||" & tabName
        end tell
        """
        return executeAndParse(script: script, browserID: "com.apple.Safari")
    }

    // MARK: - Chromium-based (Chrome, Edge, Brave, etc.)

    private func queryChromium(appName: String) -> BrowserURLInfo? {
        let script = """
        tell application "\(appName)"
            if (count of windows) = 0 then return ""
            set tabURL to URL of active tab of front window
            set tabTitle to title of active tab of front window
            return tabURL & "|||" & tabTitle
        end tell
        """
        let bundleID = NSWorkspace.shared.runningApplications
            .first { $0.localizedName == appName }?.bundleIdentifier ?? appName
        return executeAndParse(script: script, browserID: bundleID)
    }

    // MARK: - AppleScript Execution

    private func executeAndParse(script: String, browserID: String) -> BrowserURLInfo? {
        guard let appleScript = NSAppleScript(source: script) else { return nil }

        var errorDict: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorDict)

        if let error = errorDict {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -1743 = user denied automation permission
            // -600 = app not running
            if errorNumber == -1743 {
                failedBrowsers.insert(browserID)
            }
            return nil
        }

        guard let resultString = result.stringValue, !resultString.isEmpty else {
            return nil
        }

        let parts = resultString.components(separatedBy: "|||")
        let url = parts[0]
        let title = parts.count > 1 ? parts[1] : ""

        guard let parsedURL = URL(string: url) else { return nil }
        let domain = parsedURL.host ?? ""

        let storedURL: String
        if prefs.storeFullURLs {
            storedURL = url
        } else {
            storedURL = domain
        }

        return BrowserURLInfo(url: storedURL, domain: domain, pageTitle: title)
    }

    func resetFailedBrowsers() {
        failedBrowsers.removeAll()
    }
}
