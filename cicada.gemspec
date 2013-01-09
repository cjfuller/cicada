
Gem::Specification.new do |gem|

  gem.name = "cicada"
  gem.version = 0.9
  gem.date = Date.today.to_s
  gem.summary = "CICADA (Colocalization and In-situ Correction of Aberration for Distance Analysis) implementation"
  gem.description = ""
  gem.authors = ['Colin J. Fuller']
  gem.email = 'cjfuller@gmail.com'
  gem.homepage = 'http://github.com/cjfuller/colocalization3d'
  gem.add_dependency('pqueue', 'facets', 'rimageanalysistools')
  gem.add_development_dependency('rspec')
  gem.files = Dir['lib/**/*.rb']

end
  
