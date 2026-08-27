#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <ShObjIdl.h>
#include <windows.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <memory>
#include <string>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "devdox.multi_store_review";

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
    } else if (method_call.method_name().compare("isAvailable") == 0) {
      result->Success(EncodableValue(HasPackageIdentity()));
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
  /// listing.
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

    try {
      try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
      } catch (const winrt::hresult_error&) {
        // The platform thread may already be initialized with a different
        // apartment model; the agile async operation still works.
      }

      auto context =
          winrt::Windows::Services::Store::StoreContext::GetDefault();

      // StoreContext must be associated with the app window when used from
      // a Win32 (non-UWP) app, otherwise the dialog has no owner.
      context.as<IInitializeWithWindow>()->Initialize(window_);

      auto operation = context.RequestRateAndReviewAppAsync();

      // Keep the method result alive until the async operation completes;
      // method channel replies may be sent from any thread.
      auto shared_result = std::shared_ptr(std::move(result));

      operation.Completed(
          [shared_result](
              const winrt::Windows::Foundation::IAsyncOperation<
                  winrt::Windows::Services::Store::StoreRateAndReviewResult>&
                  operation,
              winrt::Windows::Foundation::AsyncStatus status) {
            if (status !=
                winrt::Windows::Foundation::AsyncStatus::Completed) {
              shared_result->Error(
                  "error", "The rate and review request failed", nullptr);
              return;
            }

            const auto review = operation.GetResults();
            if (review.Status() ==
                winrt::Windows::Services::Store::StoreRateAndReviewStatus::
                    Succeeded) {
              shared_result->Success(nullptr);
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
      result->Error("error", winrt::to_string(e.message()), nullptr);
    }
  }

  /// Opens the Microsoft Store review page for [microsoftStoreId].
  void OpenStoreListing(
      const EncodableValue* arguments,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const auto microsoft_store_id =
        GetMapStringArgument(arguments, "microsoftStoreId");
    if (!microsoft_store_id.has_value() || microsoft_store_id->empty()) {
      result->Error(
          "no-store-id",
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
    if (reinterpret_cast<int>(instance) <= 32) {
      result->Error(
          "error", "Failed to open the Microsoft Store review page",
          nullptr);
      return;
    }
    result->Success(nullptr);
  }

  HWND window_;
};

void MultiStoreReviewPluginRegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  MultiStoreReviewPlugin::RegisterWithRegistrar(registrar);
}
