#ifndef FLUTTER_PLUGIN_MULTI_STORE_REVIEW_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_MULTI_STORE_REVIEW_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#if defined(__cplusplus)
extern "C" {
#endif

#ifdef FLUTTER_PLUGIN_IMPL
#define MULTI_STORE_REVIEW_PLUGIN_EXPORT __declspec(dllexport)
#else
#define MULTI_STORE_REVIEW_PLUGIN_EXPORT __declspec(dllimport)
#endif

// Registers the plugin with the Flutter desktop engine.
MULTI_STORE_REVIEW_PLUGIN_EXPORT void MultiStoreReviewPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_MULTI_STORE_REVIEW_PLUGIN_C_API_H_
