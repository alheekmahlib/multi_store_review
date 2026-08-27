package dev.alheekmahlib.multi_store_review

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class MultiStoreReviewPluginTest {

    //
    // StoreLogic.detect
    //

    @Test
    fun detect_prefersGooglePlay_whenBothStoresInstalled() {
        assertEquals(
            AndroidStore.GOOGLE_PLAY,
            StoreLogic.detect(
                playInstalled = true,
                galleryInstalled = true,
                installerPackage = null,
            ),
        )
    }

    @Test
    fun detect_returnsAppGallery_onHuaweiOnlyDevices() {
        assertEquals(
            AndroidStore.HUAWEI_APP_GALLERY,
            StoreLogic.detect(
                playInstalled = false,
                galleryInstalled = true,
                installerPackage = null,
            ),
        )
    }

    @Test
    fun detect_returnsNull_whenNoStoreInstalled() {
        assertNull(
            StoreLogic.detect(
                playInstalled = false,
                galleryInstalled = false,
                installerPackage = null,
            ),
        )
    }

    @Test
    fun detect_prefersTheInstallerStore_overPresenceOrder() {
        // A Huawei device with both stores installed, app installed via
        // AppGallery: only AppGallery has the app listed for review.
        assertEquals(
            AndroidStore.HUAWEI_APP_GALLERY,
            StoreLogic.detect(
                playInstalled = true,
                galleryInstalled = true,
                installerPackage = "com.huawei.appmarket",
            ),
        )
    }

    @Test
    fun detect_fallsBackToPresenceOrder_forSideloadedOrUnknownInstallers() {
        assertEquals(
            AndroidStore.GOOGLE_PLAY,
            StoreLogic.detect(
                playInstalled = true,
                galleryInstalled = true,
                installerPackage = "com.android.packageinstaller",
            ),
        )
        assertEquals(
            AndroidStore.GOOGLE_PLAY,
            StoreLogic.detect(
                playInstalled = true,
                galleryInstalled = false,
                installerPackage = "com.huawei.appmarket",
            ),
        )
    }

    //
    // StoreLogic.resolve
    //

    @Test
    fun resolve_autoDetects_whenNoStoreRequested() {
        assertEquals(
            AndroidStore.HUAWEI_APP_GALLERY,
            StoreLogic.resolve(
                null,
                playInstalled = false,
                galleryInstalled = true,
                installerPackage = null,
            ),
        )
    }

    @Test
    fun resolve_honoursExplicitGooglePlayRequest() {
        assertEquals(
            AndroidStore.GOOGLE_PLAY,
            StoreLogic.resolve(
                "googlePlay",
                playInstalled = true,
                galleryInstalled = true,
            ),
        )
    }

    @Test
    fun resolve_honoursExplicitAppGalleryRequest_evenWithPlayInstalled() {
        assertEquals(
            AndroidStore.HUAWEI_APP_GALLERY,
            StoreLogic.resolve(
                "huaweiAppGallery",
                playInstalled = true,
                galleryInstalled = true,
            ),
        )
    }

    @Test
    fun resolve_returnsNull_forRequestedStoreNotInstalled() {
        assertNull(
            StoreLogic.resolve(
                "googlePlay",
                playInstalled = false,
                galleryInstalled = true,
            ),
        )
    }

    @Test
    fun resolve_returnsNull_forUnknownStoreName() {
        assertNull(
            StoreLogic.resolve(
                "mars",
                playInstalled = true,
                galleryInstalled = true,
            ),
        )
    }

    //
    // AppGalleryResults.errorFor
    //

    @Test
    fun errorFor_mapsEveryDocumentedFailureCode() {
        val expectedCodes = mapOf(
            101 to "not_released",
            104 to "invalid_huawei_id",
            105 to "conditions_not_met",
            106 to "comments_disabled",
            107 to "service_unsupported",
        )
        expectedCodes.forEach { (resultCode, errorCode) ->
            assertEquals(errorCode, AppGalleryResults.errorFor(resultCode)?.first)
        }
    }

    @Test
    fun errorFor_treatsSubmittedAndCancelledFlowsAsCompleted() {
        assertNull(AppGalleryResults.errorFor(102))
        assertNull(AppGalleryResults.errorFor(103))
        assertNull(AppGalleryResults.errorFor(108))
        assertNull(AppGalleryResults.errorFor(111))
    }

    @Test
    fun errorFor_treatsResultCanceledAsCompletion() {
        // Activity.RESULT_CANCELED is delivered when the user simply closes
        // the dialog; it must not surface as an error.
        assertNull(AppGalleryResults.errorFor(0))
    }
}
