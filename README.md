#Introduction

This package is a ruby implementation of Colocalization and In-situ Correction of Aberration for Distance Analysis (CICADA).  (See Fuller and Straight, 2012, doi:10.1111/j.1365-2818.2012.03654.x)

Depends on the [rimageanalysistools package](https://github.com/cjfuller/rimageanalysistools), which in turn depends on the [ImageAnalysisTools java library] (http://cjfuller.github.com/imageanalysistools/).  Requires jruby. (Only tested on jruby >=1.7 in ruby 1.9 mode.)

#Installing

`gem install cicada`

#Running

The gem will install an executable called cicada.  To run:

`cicada /path/to/parameters/file`

#Documentation

API documentation is available [here](http://rdoc.info/gems/cicada).

Documentation for the parameter files, including which parameters are required and their meanings, can be found on the [wiki](https://github.com/cjfuller/cicada/wiki/Parameters).

#License

Cicada is released under the MIT/X11 license.  See LICENSE for specific text.  Some dependencies of the ImageAnalysisTools library are relased under different licenses.  See that project's [license information](https://github.com/cjfuller/imageanalysistools/tree/master/LICENSES) for details.