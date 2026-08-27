#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint multi_store_review.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'multi_store_review'
  s.version          = '2.0.0'
  s.summary          = 'Flutter plugin for showing the In-App Review/System Rating pop up.'
  s.description      = <<-DESC
Flutter plugin for showing the In-App Review/System Rating pop up.
                       DESC
  s.homepage         = 'https://pub.dev/packages/multi_store_review'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Britannio Jarrett' => 'oss@britannio.dev' }
  s.source           = { :path => '.' }
  s.source_files = 'multi_store_review/Sources/multi_store_review/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'multi_store_review_privacy' => ['multi_store_review/Sources/multi_store_review/PrivacyInfo.xcprivacy']}
end
