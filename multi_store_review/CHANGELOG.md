# 1.0.0

Initial release of `multi_store_review`, an independent fork of
`in_app_review` with a new clean API.

- New `ReviewStore` enum and `detectStore()` method: detects Google Play,
  Huawei AppGallery, the Apple App Store or the Microsoft Store.
- `requestReview({ReviewStore? store})`: shows the in-app review dialog of
  the detected store by default, or of an explicitly requested store.
- Huawei AppGallery support on Android through the `guidecomment` intent —
  no HMS SDK or agconnect setup required.
- Windows: native `StoreContext.RequestRateAndReviewAppAsync` implementation
  for MSIX-packaged Microsoft Store apps, plus `openStoreListing` via the
  `ms-windows-store://` review deep link.
- Removed the `url_launcher` dependency — everything goes through the method
  channel now.
