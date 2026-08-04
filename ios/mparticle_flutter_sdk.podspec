#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mparticle_flutter_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mparticle_flutter_sdk'
  s.version          = '0.0.1'
  s.summary          = 'mParticle Flutter Wrapper'
  s.description      = <<-DESC
mParticle Flutter Wrapper
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'mparticle_flutter_sdk/Sources/mparticle_flutter_sdk/**/*.{h,m,swift}', 'mparticle_flutter_sdk/InitializeOptionsParserPackage/Sources/InitializeOptionsParser/**/*.swift'
  s.public_header_files = 'mparticle_flutter_sdk/Sources/mparticle_flutter_sdk/include/**/*.h'
  s.resource_bundles = {'mparticle_flutter_sdk_privacy' => ['mparticle_flutter_sdk/Sources/mparticle_flutter_sdk/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.dependency 'mParticle-Apple-SDK', '~> 9.2'
  s.dependency 'mParticle-Rokt'
  s.dependency 'RoktPaymentExtension'
  s.platform = :ios, '15.6'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
