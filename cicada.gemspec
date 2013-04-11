
require 'lib/cicada/version'

Gem::Specification.new do |g|

  g.name = "cicada"
  g.version = Cicada::VERSION
  g.date = '2013-01-29'
  g.summary = "CICADA implementation"  
  g.description = "CICADA (Colocalization and In-situ Correction of Aberration for Distance Analysis) implementation; see Fuller and Straight J. Microscopy (2012) doi:10.1111/j.1365-2818.2012.03654.x"
  g.authors = ['Colin J. Fuller']
  g.email = 'cjfuller@gmail.com'
  g.homepage = 'http://github.com/cjfuller/cicada'
  g.add_runtime_dependency 'pqueue'
  g.add_runtime_dependency 'facets'
  g.add_runtime_dependency 'rimageanalysistools'
  g.add_runtime_dependency 'trollop'
  g.add_development_dependency 'rspec'
  g.files = Dir['lib/**/*.rb', 'spec/**/*.rb', 'bin/**/*']
  g.executables << 'cicada'
  g.executables << 'cicada_fit_only'
  g.license = 'MIT'
  g.platform = 'java'
  g.requirements = 'jruby'

end
  
