cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "multi_store_review")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "multi_store_review_plugin")

add_library(${PLUGIN_NAME} SHARED
  "multi_store_review_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
# C++/WinRT reports failures through C++ exceptions, but the standard
# settings disable them (_HAS_EXCEPTIONS=0), which turns every WinRT failure
# into std::terminate(). Re-enable them so the plugin reports FlutterErrors.
target_compile_definitions(${PLUGIN_NAME} PRIVATE "_HAS_EXCEPTIONS=1")
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_20)
# C++/WinRT picks <coroutine> only when __cpp_lib_coroutine is defined
# (C++20). Under C++17 it includes <experimental/coroutine>, which the
# newest MSVC STL turns into a hard STL1011 static assertion.
target_include_directories(${PLUGIN_NAME}
  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include"
  INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
# Required by C++/WinRT (RoInitialize and the Windows Runtime projections).
target_link_libraries(${PLUGIN_NAME} PRIVATE windowsapp)

# List of absolute paths to libraries that should be bundled with the plugin
set(multi_store_review_bundled_libraries
  PARENT_SCOPE
)
