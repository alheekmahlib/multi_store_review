import Flutter
import StoreKit
import UIKit

public class MultiStoreReviewPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dev.alheekmahlib.multi_store_review",
            binaryMessenger: registrar.messenger())
        let instance = MultiStoreReviewPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "detectStore":
            // The deployment target is iOS 12.0, which already ships the
            // in-app review API introduced in iOS 10.3.
            result("appleAppStore")
        case "requestReview":
            let store = call.arguments as? String
            requestReview(store: store, result: result)
        case "openStoreListing":
            let args = call.arguments as? [String: Any]
            openStoreListing(storeId: args?["appStoreId"] as? String, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestReview(store: String?, result: @escaping FlutterResult) {
        if let store = store, store != "appleAppStore" {
            result(FlutterError(
                code: "unavailable_store",
                message: "The requested store (\(store)) is not available on this device",
                details: nil))
            return
        }
        if #available(iOS 16.0, *) {
            guard let scene = foregroundWindowScene else {
                result(noPresenterError)
                return
            }
            DispatchQueue.main.async {
                AppStore.requestReview(in: scene)
            }
            result("appleAppStore")
        } else if #available(iOS 14.0, *) {
            guard let scene = foregroundWindowScene else {
                result(noPresenterError)
                return
            }
            SKStoreReviewController.requestReview(in: scene)
            result("appleAppStore")
        } else {
            // iOS 12-13 have no window scenes; the legacy API targets the
            // key window on its own.
            SKStoreReviewController.requestReview()
            result("appleAppStore")
        }
    }

    private var foregroundWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
        return (scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene)
            ?? scenes.first as? UIWindowScene
    }

    private var noPresenterError: FlutterError {
        FlutterError(
            code: "no_presenter",
            message: "No foreground window scene is available to present the review dialog in",
            details: nil)
    }

    private func openStoreListing(storeId: String?, result: @escaping FlutterResult) {
        guard let storeId = storeId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !storeId.isEmpty
        else {
            result(FlutterError(
                code: "no_store_id",
                message: "Your app store id must be passed as the method channel's argument",
                details: nil))
            return
        }

        let urlString = "https://apps.apple.com/app/id\(storeId)?action=write-review"
        guard let url = URL(string: urlString) else {
            result(FlutterError(
                code: "url_construct_fail",
                message: "Failed to construct url",
                details: nil))
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                result(nil)
            } else {
                result(FlutterError(
                    code: "error",
                    message: "Failed to open the App Store listing",
                    details: nil))
            }
        }
    }
}
