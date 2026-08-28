package dev.alheekmahlib.multi_store_review

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
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
    private var binding: ActivityPluginBinding? = null

    /**
     * Result of the pending AppGallery review flow, answered in
     * [onActivityResult].
     */
    private var pendingResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "dev.alheekmahlib.multi_store_review"
        )
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "detectStore" ->
                result.success(detectStore()?.wireName ?: StoreLogic.UNAVAILABLE)
            "requestReview" -> requestReview(call.arguments as? String, result)
            "openStoreListing" -> openStoreListing(result)
            "readReviewGateState" -> result.success(readGateState())
            "writeReviewGateState" -> {
                writeGateState(call.arguments as? Map<*, *>)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
        // The engine is gone; there is nobody left to answer the pending
        // result, so drop the reference instead of leaking it.
        pendingResult = null
    }

    // ActivityAware overrides

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // The activity is recreated but the plugin stays registered; the
        // AppGallery flow result is still delivered after reattachment.
        binding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
        pendingResult?.error(
            "error",
            "The activity was destroyed before the AppGallery review flow finished",
            null
        )
        pendingResult = null
    }

    // ActivityResultListener override (AppGallery review flow)

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != APP_GALLERY_REQUEST_CODE) return false

        val result = pendingResult ?: return true
        pendingResult = null

        AppGalleryResults.errorFor(resultCode)?.let { (code, message) ->
            result.error(code, message, null)
        } ?: result.success(AndroidStore.HUAWEI_APP_GALLERY.wireName)

        return true
    }

    // Review gate state (built-in storage)

    private fun readGateState(): Map<String, Any> {
        val context = this.context ?: return emptyMap()
        val prefs = context.getSharedPreferences(GATE_PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "launches" to prefs.getInt("launches", 0),
            "firstLaunchAt" to prefs.getLong("firstLaunchAt", 0L),
            "lastPromptAt" to prefs.getLong("lastPromptAt", 0L),
        )
    }

    private fun writeGateState(state: Map<*, *>?) {
        val context = this.context ?: return
        fun value(key: String): Long =
            ((state?.get(key) as? Number)?.toLong()) ?: 0L

        context.getSharedPreferences(GATE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt("launches", ((state?.get("launches") as? Number)?.toInt()) ?: 0)
            .putLong("firstLaunchAt", value("firstLaunchAt"))
            .putLong("lastPromptAt", value("lastPromptAt"))
            .apply()
    }

    // Store detection

    private fun detectStore(): AndroidStore? {
        val context = this.context ?: return null
        return StoreLogic.detect(
            playInstalled = context.isPackageInstalled(StoreLogic.PLAY_STORE_PACKAGE),
            galleryInstalled = context.isPackageInstalled(StoreLogic.APP_GALLERY_PACKAGE),
            installerPackage = installerPackageName(),
        )
    }

    private fun Context.isPackageInstalled(name: String): Boolean =
        try {
            packageManager.getPackageInfo(name, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }

    /**
     * The package name of the store the app was installed from, used to
     * prefer that store when several are installed. Returns null when the
     * app was sideloaded or the source cannot be determined.
     */
    private fun installerPackageName(): String? {
        val context = this.context ?: return null
        val manager = context.packageManager
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val source = manager.getInstallSourceInfo(context.packageName)
                source.initiatingPackageName ?: source.installingPackageName
            } else {
                @Suppress("DEPRECATION")
                manager.getInstallerPackageName(context.packageName)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    // Review flows

    private fun requestReview(requestedStore: String?, result: Result) {
        if (noContextOrActivity(result)) return

        val store = StoreLogic.resolve(
            requested = requestedStore,
            playInstalled = context!!.isPackageInstalled(StoreLogic.PLAY_STORE_PACKAGE),
            galleryInstalled = context!!.isPackageInstalled(StoreLogic.APP_GALLERY_PACKAGE),
            installerPackage = installerPackageName(),
        )

        when (store) {
            AndroidStore.GOOGLE_PLAY -> requestPlayReview(result)
            AndroidStore.HUAWEI_APP_GALLERY -> requestAppGalleryReview(result)
            null -> {
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
                    val info = task.result
                    val flow = manager.launchReviewFlow(activity!!, info)
                    flow.addOnCompleteListener {
                        // The API does not indicate whether the user reviewed
                        // or if the dialog was shown.
                        result.success(AndroidStore.GOOGLE_PLAY.wireName)
                    }
                } else {
                    Log.w(TAG, "requestPlayReview: review flow unavailable")
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

    /**
     * Shows the AppGallery rating dialog. AppGallery renders the dialog
     * itself in response to the guidecomment intent, so no HMS SDK is
     * required. Result codes are documented in [AppGalleryResults].
     */
    private fun requestAppGalleryReview(result: Result) {
        try {
            val intent = Intent(GUIDE_COMMENT_ACTION)
                .setPackage(StoreLogic.APP_GALLERY_PACKAGE)
            // Fail a still-pending previous result instead of leaking its
            // Dart future forever.
            pendingResult?.error(
                "error",
                "A new review request superseded the pending AppGallery flow",
                null
            )
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
                        Intent(Intent.ACTION_VIEW).setData(Uri.parse(deepLink))
                    )
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    launch(marketFallback, result)
                }
            }
            null -> result.error(
                "unavailable_store",
                "No supported app store is installed on this device",
                null
            )
        }
    }

    private fun launch(url: String, result: Result) {
        try {
            activity!!.startActivity(
                Intent(Intent.ACTION_VIEW).setData(Uri.parse(url))
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
        if (context == null) {
            result?.error("error", "Android context not available", null)
            return true
        }

        if (activity == null) {
            result?.error("error", "Android activity not available", null)
            return true
        }

        return false
    }

    companion object {
        private const val TAG = "MultiStoreReviewPlugin"

        /** Intent action rendered by AppGallery as the in-app rating dialog. */
        private const val GUIDE_COMMENT_ACTION =
            "com.huawei.appmarket.intent.action.guidecomment"

        private const val APP_GALLERY_REQUEST_CODE = 1001

        /** SharedPreferences file holding the built-in review gate state. */
        private const val GATE_PREFS = "dev.alheekmahlib.multi_store_review.gate"
    }
}

/** The stores this plugin can route to on Android. */
internal enum class AndroidStore(val wireName: String) {
    GOOGLE_PLAY("googlePlay"),
    HUAWEI_APP_GALLERY("huaweiAppGallery"),
}

/**
 * Pure store-selection logic, kept free of Android dependencies for testing.
 * A null result means no supported store is present on the device.
 */
internal object StoreLogic {

    /** Wire name reported when no supported store is present. */
    const val UNAVAILABLE = "unavailable"

    /** Google Play Store package name. */
    const val PLAY_STORE_PACKAGE = "com.android.vending"

    /** Huawei AppGallery package name. */
    const val APP_GALLERY_PACKAGE = "com.huawei.appmarket"

    /**
     * Picks the store to use, preferring the store the app was installed
     * from — on devices with several stores only the installing one has the
     * app listed for review. Falls back to presence order (Play first).
     */
    fun detect(
        playInstalled: Boolean,
        galleryInstalled: Boolean,
        installerPackage: String?,
    ): AndroidStore? = when {
        installerPackage == PLAY_STORE_PACKAGE && playInstalled ->
            AndroidStore.GOOGLE_PLAY
        installerPackage == APP_GALLERY_PACKAGE && galleryInstalled ->
            AndroidStore.HUAWEI_APP_GALLERY
        playInstalled -> AndroidStore.GOOGLE_PLAY
        galleryInstalled -> AndroidStore.HUAWEI_APP_GALLERY
        else -> null
    }

    /**
     * Resolves the store to use for an explicit (non-null) request. The
     * caller is responsible for reporting a null result with an
     * `unavailable_store` error.
     */
    fun resolve(
        requested: String?,
        playInstalled: Boolean,
        galleryInstalled: Boolean,
        installerPackage: String? = null,
    ): AndroidStore? = when (requested) {
        null -> detect(playInstalled, galleryInstalled, installerPackage)
        AndroidStore.GOOGLE_PLAY.wireName ->
            if (playInstalled) AndroidStore.GOOGLE_PLAY else null
        AndroidStore.HUAWEI_APP_GALLERY.wireName ->
            if (galleryInstalled) AndroidStore.HUAWEI_APP_GALLERY else null
        else -> null
    }
}

/**
 * Maps AppGallery review-flow result codes to plugin errors. A null result
 * means the flow completed (comment submitted or dialog dismissed),
 * mirroring the void contract of the Play review flow.
 */
internal object AppGalleryResults {

    fun errorFor(resultCode: Int): Pair<String, String>? = when (resultCode) {
        101 -> "not_released" to "The app has not been released on AppGallery"
        104 -> "invalid_huawei_id" to "The HUAWEI ID sign-in status is invalid"
        105 -> "conditions_not_met" to
            "The user does not meet the conditions for displaying the comment pop-up"
        106 -> "comments_disabled" to "The commenting function is disabled"
        107 -> "service_unsupported" to "The in-app commenting service is not supported"
        // Activity.RESULT_CANCELED (0) and the remaining codes complete the
        // flow (user cancelled or dismissed the dialog), matching the Play
        // review flow contract.
        else -> null
    }
}
