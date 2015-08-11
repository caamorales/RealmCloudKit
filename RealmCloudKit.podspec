Pod::Spec.new do |s|
  s.name             = "RealmCloudKit"
  s.version          = "0.1.0"
  s.summary          = "A Swift library built on top of Realm to sync data using CloudKit."
  s.homepage         = "https://github.com/BellAppLab/RealmCloudKit"
  s.license          = 'MIT'
  s.author           = { "Bell App Lab" => "apps@bellapplab.com" }
  s.source           = { :git => "https://github.com/BellAppLab/RealmCloudKit.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/BellAppLab'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'

  s.frameworks = 'Foundation', 'CloudKit', 'Security'
  s.dependency 'MultiRealm'
  s.dependency 'SwiftFileManager'
  s.dependency 'CryptoSwift'
end
