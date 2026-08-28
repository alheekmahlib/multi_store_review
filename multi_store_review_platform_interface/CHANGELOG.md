# 2.2.0

- Additive: `StoreListing.macAppStoreId` for apps with a separate macOS
  listing; `appStoreId` remains the fallback. The `openStoreListing` wire
  map now carries a `macAppStoreId` key.

# 2.1.0

- Additive: `readReviewGateState()` / `writeReviewGateState(...)` platform
  methods and the `ReviewGateState` value they exchange, used by the
  app-facing automatic review gate. Best-effort contract: reads return an
  empty state when nothing was persisted; writes of the empty state clear
  it.

# 2.0.0

Breaking change, reworked together with the app-facing `multi_store_review`
2.0.0 release:

- `detectStore()` now returns `Future<ReviewStore?>`; `null` means no
  supported store was detected. The `ReviewStore.unavailable` sentinel value
  was removed and `ReviewStore.fromName(String?)` was added for parsing
  wire names.
- `isAvailable()` was replaced by `canRequestReview()`, which by default
  derives from `detectStore()` (single source of truth). Implementations no
  longer need a separate `isAvailable` channel method.
- `requestReview({ReviewStore? store})` now returns the
  `Future<ReviewStore>` that was used, and the method-channel implementation
  deduplicates concurrent calls.
- `openStoreListing` takes a `StoreListing` value object instead of loose
  named parameters and rejects blank ids.
- New `MultiStoreReviewErrorCode` constants document the error codes shared
  with the platform implementations.
- `MethodChannelMultiStoreReview` receives its channel and platform through
  constructor injection.

# 1.0.0

Initial release of the `multi_store_review` platform interface.

- `detectStore`, `isAvailable`, `requestReview({ReviewStore? store})` and
  `openStoreListing` platform interface methods.
- `ReviewStore` enum shared by the app-facing package and platform
  implementations.
