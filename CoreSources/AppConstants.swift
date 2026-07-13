import Foundation

enum AppConstants {
    static let appName = "MacPulse"
    static let developerName = "TerabitLab"
    static let developerURL = URL(string: "https://terabitlab.com/")!

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.macpulse.local.MacPulse"
    }
    static let widgetBundleIdentifier = "com.macpulse.local.MacPulse.Widget"

    static let overviewWidgetKind = "com.macpulse.local.MacPulse.overview"
    static let cpuWidgetKind = "com.macpulse.local.MacPulse.cpu"
    static let gpuWidgetKind = "com.macpulse.local.MacPulse.gpu"
    static let allWidgetKinds = [overviewWidgetKind, cpuWidgetKind, gpuWidgetKind]

    static let sharedPayloadFilename = "macpulse-payload-v3.json"
    static let sharedPayloadKey = "sharedPayload.v3"
    static let payloadSchemaVersion = 3
    static let maximumPersistedHistoryPoints = 180
    static let repositoryURL = URL(string: "https://github.com/vluncasu/macpulse")!
    static let privacyURL = URL(string: "https://github.com/vluncasu/macpulse/blob/main/docs/PRIVACY.md")!
}
