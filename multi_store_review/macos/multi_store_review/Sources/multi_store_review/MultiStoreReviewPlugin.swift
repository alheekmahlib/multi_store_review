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
        case "requestReview":
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
                guard let viewController = NSApplication.shared.mainWindow? .contentViewController else {
                    result(
                        FlutterError(
                            code: "no-view-controller",
                            message: "Could not get main view controller",
                            details: nil))
                    return
                }
                DispatchQueue.main.async {
                    AppStore.requestReview(in: viewController)
                }
            } else if #available(OSX 10.14, *) {
                SKStoreReviewController.requestReview()
            } else {
                result(
                    FlutterError(
                        code: "unavailable",
                        message: "In-App Review unavailable", details: nil))
            }
            result(nil)
        case "isAvailable":
            if #available(OSX 10.14, *) {
                result(true)
            } else {
                result(false)
            }
        case "detectStore":
            if #available(OSX 10.14, *) {
                result("appleAppStore")
            } else {
                result("unavailable")
            }
        case "openStoreListing":
            let args = call.arguments as? [String: Any]
            guard let storeId = args?["appStoreId"] as? String else {
                result(
                    FlutterError(
                        code: "no-store-id",
                        message: "Your store id must be passed as the method channel's argument",
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
