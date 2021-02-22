Pod::Spec.new do |s|
  s.name = 'HAWebSocket'
  s.version = '0.1.0'
  s.summary = 'A short description of WebSocket.'
  s.author = 'Home Assistant'

  s.description = 'Home Assistant WebSocket'

  s.homepage = 'https://github.com/home-assistant/<tbd>'
  s.license = { type: 'Apache 2', file: 'LICENSE.md' }
  s.source = { git: 'https://github.com/home-assistant.git', tag: s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.watchos.deployment_target = '5.0'
  s.macos.deployment_target = '10.14'

  s.source_files = 'Source/**/*.swift'
  s.dependency 'Starscream', '~> 4.0.4'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/*.swift'
  end
end
