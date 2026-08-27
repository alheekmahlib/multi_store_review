# multi_store_review_platform_interface

A common platform interface for the [`multi_store_review`][1] plugin.

This interface allows platform-specific implementations of the `multi_store_review`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

To implement a new platform-specific implementation of `multi_store_review`, extend
[`MultiStoreReviewPlatform`][2] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`MultiStoreReviewPlatform` by calling
`MultiStoreReviewPlatform.instance = MyMultiStoreReview()`.

# Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface)
over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion
on why a less-clean interface is preferable to a breaking change.

[1]: ../multi_store_review
[2]: lib/multi_store_review_platform_interface.dart