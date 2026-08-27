package devdox.multi_store_review

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.net.toUri
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** MultiStoreReviewPlugin */
class MultiStoreReviewPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null

    /// Result of the pending AppGallery review flow, answered in onActivityResult.
    private var pendingResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "devdox.multi_store_review"
        )
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.i(TAG, "onMethodCall: ${call.method}")
        when (call.method) {
            "detectStore" -> result.success(detectStore().wireName)
            "isAvailable" -> result.success(detectStore() != AndroidStore.UNAVAILABLE)
            "requestReview" -> requestReview(call.arguments as? String, result)
            "openStoreListing" -> openStoreListing(result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    // ActivityAware overrides

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ActivityResultListener override (AppGallery review flow)

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != APP_GALLERY_REQUEST_CODE) return false

        val result = pendingResult ?: return true
        pendingResult = null

        AppGalleryResults.errorFor(resultCode)?.let { (code, message) ->
            result.error(code, message, null)
        } ?: result.success(null)

        return true
    }

    // Store detection

    private fun detectStore(): AndroidStore {
        val context = this.context ?: return AndroidStore.UNAVAILABLE
        return StoreLogic.detect(
            playInstalled = context.isPackageInstalled(PLAY_STORE_PACKAGE),
            galleryInstalled = context.isPackageInstalled(APP_GALLERY_PACKAGE),
        )
    }

    private fun Context.isPackageInstalled(name: String): Boolean =
        try {
            packageManager.getPackageInfo(name, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }

    // Review flows

    private fun requestReview(requestedStore: String?, result: Result) {
        Log.i(TAG, "requestReview: called (store=$requestedStore)")
        if (noContextOrActivity(result)) return

        val store = StoreLogic.resolve(
            requested = requestedStore,
            playInstalled = context!!.isPackageInstalled(PLAY_STORE_PACKAGE),
            galleryInstalled = context!!.isPackageInstalled(APP_GALLERY_PACKAGE),
        )

        when (store) {
            AndroidStore.GOOGLE_PLAY -> requestPlayReview(result)
            AndroidStore.HUAWEI_APP_GALLERY -> requestAppGalleryReview(result)
            AndroidStore.UNAVAILABLE -> {
                val message = if (requestedStore == null) {
                    "No supported app store is installed on this device"
                } else {
                    "The requested store ($requestedStore) is not available on this device"
                }
                result.error("unavailable_store", message, null)
            }
        }
    }

    private fun requestPlayReview(result: Result) {
        try {
            val manager = ReviewManagerFactory.create(context!!)
            val request = manager.requestReviewFlow()
            request.addOnCompleteListener { task ->
                if (noContextOrActivity(result)) return@addOnCompleteListener
                if (task.isSuccessful) {
                    Log.i(TAG, "onComplete: Successfully requested review flow")
                    val info = task.result
                    val flow = manager.launchReviewFlow(activity!!, info)
                    flow.addOnCompleteListener {
                        // The API does not indicate whether the user reviewed or if the dialog was shown.
                        result.success(null)
                    }
                } else {
                    Log.w(TAG, "onComplete: Unsuccessfully requested review flow")
                    result.error(
                        "error",
                        "In-App Review API unavailable",
                        null
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "requestPlayReview: error", e)
            result.error(
                "error",
                "An error occurred during the request review flow",
                null
            )
        }
    }

    /// Shows the AppGallery rating dialog. AppGallery renders the dialog
    /// itself in response to the guidecomment intent, so no HMS SDK is
    /// required. Result codes are documented in [AppGalleryResults].
    private fun requestAppGalleryReview(result: Result) {
        try {
            val intent = Intent(GUIDE_COMMENT_ACTION)
                .setPackage(APP_GALLERY_PACKAGE)
            pendingResult = result
            activity!!.startActivityForResult(intent, APP_GALLERY_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pendingResult = null
            result.error(
                "unavailable_store",
                "Huawei AppGallery is not installed on this device",
                null
            )
        } catch (e: Exception) {
            pendingResult = null
            Log.e(TAG, "requestAppGalleryReview: error", e)
            result.error(
                "error",
                "An error occurred while launching the AppGallery review flow",
                null
            )
        }
    }

    // Store listing

    private fun openStoreListing(result: Result) {
        Log.i(TAG, "openStoreListing: called")
        if (noContextOrActivity(result)) return

        val packageName = context!!.packageName
        when (detectStore()) {
            AndroidStore.GOOGLE_PLAY -> launch(
                "https://play.google.com/store/apps/details?id=$packageName",
                result,
            )
            AndroidStore.HUAWEI_APP_GALLERY -> {
                val deepLink = "appmarket://details?id=$packageName"
                val marketFallback = "market://details?id=$packageName"
                try {
                    activity!!.startActivity(
                        Intent(Intent.ACTION_VIEW).setData(deepLink.toUri())
                    )
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    launch(marketFallback, result)
                }
            }
            AndroidStore.UNAVAILABLE -> result.error(
                "unavailable_store",
                "No supported app store is installed on this device",
                null
            )
        }
    }

    private fun launch(url: String, result: Result) {
        try {
            activity!!.startActivity(
                Intent(Intent.ACTION_VIEW).setData(url.toUri())
            )
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error(
                "error",
                "No activity found to open $url",
                null
            )
        } catch (e: Exception) {
            Log.e(TAG, "launch: error", e)
            result.error(
                "error",
                "An error occurred while opening the store listing",
                null
            )
        }
    }

    private fun noContextOrActivity(result: Result? = null): Boolean {
        Log.i(TAG, "noContextOrActivity: called")

        if (context == null) {
            val msg = "Android context not available"
            Log.e(TAG, "noContextOrActivity: $msg")
            result?.error("error", msg, null)
            return true
        }

        if (activity == null) {
            val msg = "Android activity not available"
            Log.e(TAG, "noContextOrActivity: $msg")
            result?.error("error", msg, null)
            return true
        }

        return false
    }

    companion object {
        private const val TAG = "MultiStoreReviewPlugin"

        /// Google Play Store package name.
        private const val PLAY_STORE_PACKAGE = "com.android.vending"

        /// Huawei AppGallery package name.
        private const val APP_GALLERY_PACKAGE = "com.huawei.appmarket"

        /// Intent action rendered by AppGallery as the in-app rating dialog.
        private const val GUIDE_COMMENT_ACTION =
            "com.huawei.appmarket.intent.action.guidecomment"

        private const val APP_GALLERY_REQUEST_CODE = 1001
    }
}

/// The stores this plugin can route to on Android.
internal enum class AndroidStore(val wireName: String) {
    GOOGLE_PLAY("googlePlay"),
    HUAWEI_APP_GALLERY("huaweiAppGallery"),
    UNAVAILABLE("unavailable"),
}

/// Pure store-selection logic, kept free of Android dependencies for testing.
internal object StoreLogic {

    /// Prefers Google Play when both stores are installed.
    fun detect(playInstalled: Boolean, galleryInstalled: Boolean): AndroidStore =
        when {
            playInstalled -> AndroidStore.GOOGLE_PLAY
            galleryInstalled -> AndroidStore.HUAWEI_APP_GALLERY
            else -> AndroidStore.UNAVAILABLE
        }

    /// Resolves the store to use for an explicit (non-null) request. The
    /// caller is responsible for reporting [AndroidStore.UNAVAILABLE] with
    /// an `unavailable_store` error.
    fun resolve(
        requested: String?,
        playInstalled: Boolean,
        galleryInstalled: Boolean,
    ): AndroidStore = when (requested) {
        null -> detect(playInstalled, galleryInstalled)
        AndroidStore.GOOGLE_PLAY.wireName ->
            if (playInstalled) AndroidStore.GOOGLE_PLAY else AndroidStore.UNAVAILABLE
        AndroidStore.HUAWEI_APP_GALLERY.wireName ->
            if (galleryInstalled) AndroidStore.HUAWEI_APP_GALLERY
            else AndroidStore.UNAVAILABLE
        else -> AndroidStore.UNAVAILABLE
    }
}

/// Maps AppGallery review-flow result codes to plugin errors. A null result
/// means the flow completed (comment submitted or user cancelled), mirroring
/// the void contract of the Play review flow.
internal object AppGalleryResults {

    fun errorFor(resultCode: Int): Pair<String, String>? = when (resultCode) {
        0 -> "unknown_error" to "Unknown error while showing the AppGallery review dialog"
        101 -> "not_released" to "The app has not been released on AppGallery"
        104 -> "invalid_huawei_id" to "The HUAWEI ID sign-in status is invalid"
        105 -> "conditions_not_met" to
            "The user does not meet the conditions for displaying the comment pop-up"
        106 -> "comments_disabled" to "The commenting function is disabled"
        107 -> "service_unsupported" to "The in-app commenting service is not supported"
        else -> null
    }
}
