package devdox.multi_store_review

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
            StoreLogic.detect(playInstalled = true, galleryInstalled = true),
        )
    }

    @Test
    fun detect_returnsAppGallery_onHuaweiOnlyDevices() {
        assertEquals(
            AndroidStore.HUAWEI_APP_GALLERY,
            StoreLogic.detect(playInstalled = false, galleryInstalled = true),
        )
    }

    @Test
    fun detect_returnsUnavailable_whenNoStoreInstalled() {
        assertEquals(
            AndroidStore.UNAVAILABLE,
            StoreLogic.detect(playInstalled = false, galleryInstalled = false),
        )
    }

    //
    // StoreLogic.resolve
    //

    @Test
    fun resolve_autoDetects_whenNoStoreRequested() {
        assertEquals(
            AndroidStore.HUAWEI_APP_GALLERY,
            StoreLogic.resolve(null, playInstalled = false, galleryInstalled = true),
        )
    }

    @Test
    fun resolve_honoursExplicitGooglePlayRequest() {
        assertEquals(
            AndroidStore.GOOGLE_PLAY,
            StoreLogic.resolve("googlePlay", playInstalled = true, galleryInstalled = true),
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
    fun resolve_returnsUnavailable_forRequestedStoreNotInstalled() {
        assertEquals(
            AndroidStore.UNAVAILABLE,
            StoreLogic.resolve("googlePlay", playInstalled = false, galleryInstalled = true),
        )
    }

    @Test
    fun resolve_returnsUnavailable_forUnknownStoreName() {
        assertEquals(
            AndroidStore.UNAVAILABLE,
            StoreLogic.resolve("mars", playInstalled = true, galleryInstalled = true),
        )
    }

    //
    // AppGalleryResults.errorFor
    //

    @Test
    fun errorFor_mapsEveryDocumentedFailureCode() {
        val expectedCodes = mapOf(
            0 to "unknown_error",
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
    }
}
