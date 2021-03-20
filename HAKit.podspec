Pod::Spec.new do |s|
  s.name = 'HAKit'
  s.version = '0.1.0'
  s.summary = 'Communicate with a Home Assistant instance.'
  s.author = 'Home Assistant'

  s.homepage = 'https://github.com/home-assistant/HAKit'
  s.license = { type: 'Apache 2', file: 'LICENSE.md' }
  s.source = { git: 'https://github.com/home-assistant/HAKit.git', tag: s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'
  s.watchos.deployment_target = '5.0'
  s.macos.deployment_target = '10.14'

  s.swift_versions = ['5.3']

  s.source_files = 'Source/**/*.swift'
  s.dependency 'Starscream', '~> 4.0.4'

  s.subspec 'PromiseKit' do |subspec|
    subspec.dependency 'PromiseKit', '~> 6.13'
    subspec.source_files = 'Extensions/PromiseKit/**/*.swift'
  end

  s.subspec 'Mocks' do |subspec|
    subspec.source_files = 'Extensions/Mocks/**/*.swift'
  end

  s.test_spec 'Tests' do |test_spec|
    test_spec.platform = :ios, '12.0'
    test_spec.macos.deployment_target = '10.14'
    test_spec.source_files = 'Tests/*.swift'
  end
end
