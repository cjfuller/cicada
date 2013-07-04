#--
# /* ***** BEGIN LICENSE BLOCK *****
#  * 
#  * Copyright (c) 2013 Colin J. Fuller
#  * 
#  * Permission is hereby granted, free of charge, to any person obtaining a copy
#  * of this software and associated documentation files (the Software), to deal
#  * in the Software without restriction, including without limitation the rights
#  * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  * copies of the Software, and to permit persons to whom the Software is
#  * furnished to do so, subject to the following conditions:
#  * 
#  * The above copyright notice and this permission notice shall be included in
#  * all copies or substantial portions of the Software.
#  * 
#  * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  * SOFTWARE.
#  * 
#  * ***** END LICENSE BLOCK ***** */
#++

require 'rimageanalysistools'
require 'rimageanalysistools/image_shortcuts'
require 'rimageanalysistools/create_parameters'

require 'cicada/correction/position_corrector'

java_import Java::edu.stanford.cfuller.imageanalysistools.image.ImageFactory

module Cicada
	class AberrationMap

		def self.generate(c, bounds_x, bounds_y, params)
			size_x = bounds_x[1] - bounds_x[0]
			size_y = bounds_y[1] - bounds_y[0]
			ab_map = ImageFactory.createWritable(ImageCoordinate[size_x, size_y, 3,1, 1], 0.0)
			ab_map.setBoxOfInterest(ImageCoordinate[0,0,0,0,0], ImageCoordinate[size_x, size_y, 1, 1, 1])
			ic2 = ImageCoordinate[0,0,0,0,0]
			dist_conv = [params[:pixelsize_nm].to_f, params[:pixelsize_nm].to_f, params[:z_sectionsize_nm].to_f]

			ab_map.each do |ic|
				ic2.setCoord(ic)
				corr = c.correct_position(ic[:x] + bounds_x[0], ic[:y] + bounds_y[0])
				0.upto(2) do |dim|
					ic2[:z] = dim
					ab_map[ic2] = corr[dim] * dist_conv[dim]
				end
			end
			ab_map
		end
	end
end
