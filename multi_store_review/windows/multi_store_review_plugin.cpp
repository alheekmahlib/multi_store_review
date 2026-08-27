#include "multi_store_review/multi_store_review_plugin_c_api.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <ShObjIdl.h>
#include <windows.h>
#include <appmodel.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <memory>
#include <optional>
#include <string>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "dev.alheekmahlib.multi_store_review";

/// The Microsoft Store rate & review API only works for packaged (MSIX)
/// apps distributed through the store. GetCurrentPackageFullName returns
/// APPMODEL_ERROR_NO_PACKAGE for unpackaged apps.
bool HasPackageIdentity() {
  uint32_t buffer_length = 0;
  return GetCurrentPackageFullName(&buffer_length, nullptr) !=
         APPMODEL_ERROR_NO_PACKAGE;
}

std::string DetectStore() {
  return HasPackageIdentity() ? "microsoftStore" : "unavailable";
}

std::optional<std::string> GetStringArgument(
    const EncodableValue* arguments) {
  if (arguments == nullptr) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<std::string>(arguments)) {
    return *value;
  }
  return std::nullopt;
}

std::optional<std::string> GetMapStringArgument(
    const EncodableValue* arguments, const char* key) {
  if (arguments == nullptr) {
    return std::nullopt;
  }
  const auto* map = std::get_if<EncodableMap>(arguments);
  if (map == nullptr) {
    return std::nullopt;
  }
  const auto it = map->find(EncodableValue(key));
  if (it == map->end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return std::nullopt;
}

std::wstring ToWideString(const std::string& narrow) {
  if (narrow.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(
      CP_UTF8, 0, narrow.c_str(), static_cast<int>(narrow.size()), nullptr, 0);
  std::wstring wide(size, L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, narrow.c_str(), static_cast<int>(narrow.size()),
      wide.data(), size);
  return wide;
}

}  // namespace

class MultiStoreReviewPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel =
        std::make_unique<flutter::MethodChannel<EncodableValue>>(
            registrar->messenger(), kChannelName,
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<MultiStoreReviewPlugin>(
        GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT));

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](
            const flutter::MethodCall<EncodableValue>& call,
            std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  MultiStoreReviewPlugin(HWND window) : window_(window) {}

  virtual ~MultiStoreReviewPlugin() = default;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    if (method_call.method_name().compare("detectStore") == 0) {
      result->Success(EncodableValue(DetectStore()));
    } else if (method_call.method_name().compare("requestReview") == 0) {
      RequestReview(method_call.arguments(), std::move(result));
    } else if (method_call.method_name().compare("openStoreListing") == 0) {
      OpenStoreListing(method_call.arguments(), std::move(result));
    } else {
      result->NotImplemented();
    }
  }

  /// Shows the Microsoft Store rating dialog through the WinRT
  /// StoreContext::RequestRateAndReviewAppAsync API. Requires package
  /// identity, otherwise an `unavailable_store` error is reported so that
  /// apps distributed outside the store can fall back to opening the store
  /// listing. Completes with "microsoftStore" when the dialog flow ran,
  /// including a user cancellation.
  void RequestReview(
      const EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const auto requested_store = GetStringArgument(arguments);
    if (requested_store.has_value() && *requested_store != "microsoftStore") {
      result->Error(
          "unavailable_store",
          "The requested store (" + *requested_store +
              ") is not available on this device",
          nullptr);
      return;
    }

    if (!HasPackageIdentity()) {
      result->Error(
          "unavailable_store",
          "The Microsoft Store review dialog requires an MSIX-packaged app",
          nullptr);
      return;
    }

    // The completion handler runs on a WinRT thread worker while the catch
    // below runs on the platform thread; share ownership of the result so
    // exactly one of them replies.
    auto shared_result = std::shared_ptr(std::move(result));

    try {
      auto context =
          winrt::Windows::Services::Store::StoreContext::GetDefault();

      // StoreContext must be associated with the app window when used from
      // a Win32 (non-UWP) app, otherwise the dialog has no owner.
      context.as<IInitializeWithWindow>()->Initialize(window_);

      auto operation = context.RequestRateAndReviewAppAsync();

      operation.Completed(
          [shared_result](
              const winrt::Windows::Foundation::IAsyncOperation<
                  winrt::Windows::Services::Store::StoreRateAndReviewResult>&
                  operation,
              winrt::Windows::Foundation::AsyncStatus status) {
            // A user cancelling resolves like on Android & iOS instead of
            // surfacing as an error.
            if (status ==
                winrt::Windows::Foundation::AsyncStatus::Canceled) {
              shared_result->Success(EncodableValue("microsoftStore"));
              return;
            }
            if (status !=
                winrt::Windows::Foundation::AsyncStatus::Completed) {
              shared_result->Error(
                  "error", "The rate and review request failed", nullptr);
              return;
            }

            const auto review = operation.GetResults();
            const auto review_status = review.Status();
            if (review_status == winrt::Windows::Services::Store::
                                    StoreRateAndReviewStatus::Succeeded ||
                review_status ==
                    winrt::Windows::Services::Store::StoreRateAndReviewStatus::
                        CanceledByUser) {
              shared_result->Success(EncodableValue("microsoftStore"));
              return;
            }

            const auto extended_error = review.ExtendedError().value;
            if (extended_error != S_OK) {
              shared_result->Error(
                  "error",
                  winrt::to_string(
                      winrt::hresult_error(extended_error).message()),
                  nullptr);
            } else {
              shared_result->Error(
                  "error",
                  "The rate and review request did not succeed",
                  nullptr);
            }
          });
    } catch (const winrt::hresult_error& e) {
      shared_result->Error("error", winrt::to_string(e.message()), nullptr);
    } catch (...) {
      shared_result->Error(
          "error",
          "An unexpected error occurred during the rate and review request",
          nullptr);
    }
  }

  /// Opens the Microsoft Store review page for the given microsoftStoreId.
  void OpenStoreListing(
      const EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const auto microsoft_store_id =
        GetMapStringArgument(arguments, "microsoftStoreId");
    if (!microsoft_store_id.has_value() || microsoft_store_id->empty()) {
      result->Error(
          "no_store_id",
          "Your microsoft store id must be passed as the method channel's "
          "argument",
          nullptr);
      return;
    }

    const std::wstring url =
        L"ms-windows-store://review/?ProductId=" +
        ToWideString(*microsoft_store_id);
    const HINSTANCE instance =
        ShellExecuteW(window_, L"open", url.c_str(), nullptr, nullptr,
                      SW_SHOWNORMAL);
    // ShellExecuteW returns a value <= 32 on failure.
    if (reinterpret_cast<INT_PTR>(instance) <= 32) {
      result->Error(
          "error", "Failed to open the Microsoft Store review page",
          nullptr);
      return;
    }
    result->Success(nullptr);
  }

  HWND window_;
};

void MultiStoreReviewPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  MultiStoreReviewPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
