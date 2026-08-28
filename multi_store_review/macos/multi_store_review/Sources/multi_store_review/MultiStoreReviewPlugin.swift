import Cocoa
import FlutterMacOS
import StoreKit

public class MultiStoreReviewPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dev.alheekmahlib.multi_store_review",
            binaryMessenger: registrar.messenger)
        let instance = MultiStoreReviewPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(
        _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
        switch call.method {
        case "detectStore":
            if #available(OSX 10.14, *) {
                result("appleAppStore")
            } else {
                result("unavailable")
            }        case "requestReview":
            let store = call.arguments as? String
            if let store = store, store != "appleAppStore" {
                result(
                    FlutterError(
                        code: "unavailable_store",
                        message: "The requested store (\(store)) is not available on this device",
                        details: nil))
                return
            }
            if #available(OSX 13.0, *) {
                guard let viewController = NSApplication.shared.mainWindow?.contentViewController else {
                    result(
                        FlutterError(
                            code: "no_presenter",
                            message: "Could not get the main window's view controller",
                            details: nil))
                    return
                }
                DispatchQueue.main.async {
                    AppStore.requestReview(in: viewController)
                }
                result("appleAppStore")
            } else if #available(OSX 10.14, *) {
                SKStoreReviewController.requestReview()
                result("appleAppStore")
            } else {
                result(
                    FlutterError(
                        code: "unavailable_store",
                        message: "In-App Review requires macOS 10.14 or newer",
                        details: nil))
            }
        case "openStoreListing":
            let args = call.arguments as? [String: Any]
            let rawStoreId = (args?["appStoreId"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let storeId = rawStoreId, !storeId.isEmpty else {
                result(
                    FlutterError(
                        code: "no_store_id",
                        message: "Your app store id must be passed as the method channel's argument",
                        details: nil))
                return
            }

            guard
                let writeReviewURL = URL(
                    string: "macappstore://apps.apple.com/app/id" + storeId
                        + "?action=write-review")
            else {
                result(
                    FlutterError(
                        code: "url_construct_fail",
                        message: "Failed to construct url", details: nil))
                return
            }
            NSWorkspace.shared.open(writeReviewURL)
            result(nil)
        case "readReviewGateState":
            result(readGateState())
        case "writeReviewGateState":
            writeGateState(call.arguments as? [String: Any])
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Review gate state (built-in storage via UserDefaults)

    private var gateDefaults: UserDefaults { UserDefaults.standard }

    private func readGateState() -> [String: Int64] {
        func value(_ key: String) -> Int64 {
            (gateDefaults.object(forKey: key) as? NSNumber)?.int64Value ?? 0
        }
        return [
            "launches": value("multi_store_review.launches"),
            "firstLaunchAt": value("multi_store_review.firstLaunchAt"),
            "lastPromptAt": value("multi_store_review.lastPromptAt"),
        ]
    }

    private func writeGateState(_ state: [String: Any]?) {
        func value(_ key: String) -> Int64 {
            (state?[key] as? NSNumber)?.int64Value ?? 0
        }
        gateDefaults.set(value("launches"), forKey: "multi_store_review.launches")
        gateDefaults.set(value("firstLaunchAt"), forKey: "multi_store_review.firstLaunchAt")
        gateDefaults.set(value("lastPromptAt"), forKey: "multi_store_review.lastPromptAt")
    }
}
