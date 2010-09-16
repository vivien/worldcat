Gem::Specification.new do |spec|
  spec.name = 'worldcat'
  spec.author = 'Vivien Didelot'
  spec.email = 'vivien.didelot@gmail.com'
  spec.version = '0.0.1'
  spec.summary = 'A Ruby API for the WorldCat Search webservices'
  spec.require_path = 'lib'
  spec.files = Dir['lib/**/*']
  spec.files << 'README.rdoc'
  spec.files << 'CHANGELOG.rdoc'
  spec.add_dependency 'simple-rss', '>= 1.2.3'
  spec.add_dependency 'marc', '>= 0.3.3'
  spec.add_dependency 'cql-ruby', '>= 0.8.2'
end
