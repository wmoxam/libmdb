Gem::Specification.new do |spec|
  spec.name = 'libmdb'
  spec.author = 'Wesley Moxam'
  spec.email = 'wesley.moxam@learnhub.com'
  spec.add_dependency('ffi', '>= 1.1.5')
  spec.description = 'A low level Ruby wrapper for mdbtools'
  spec.summary = 'MS Access DB raw API'
  spec.files = Dir['README', 'lib/**/*', 'lib/**/**/*']
  spec.require_paths = ["lib"]
  spec.homepage = 'https://github.com/wmoxam/libmdb'
  spec.required_ruby_version = '>= 1.8.7'
  spec.version = '0.1.2'
end
