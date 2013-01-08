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

require 'cicada/mutable_matrix'

require 'cicada/correction/correction'

module Cicada

  class PositionCorrector

    REQUIRED_PARAMETERS = [:pixelsize_nm, :z_sectionsize_nm, :num_points, :reference_channel, :channel_to_correct]

    OPTIONAL_PARAMETERS = [:determine_correction, :max_threads, :in_situ_aberr_corr_channel, :inverted_z_axis]

    NUM_CORR_PARAM = 6

    attr_accessor :parameters, :pixel_to_distance_conversions

    def initialize(p)
      @parameters = p
      @pixel_to_distance_conversions = Vector[p[:pixelsize_nm], p[:pixelsize_nm], p[:z_sectionsize_nm]]
    end

    def generate_correction(iobjs)
      
      ref_ch = parameters[:reference_channel]
      corr_ch = parameters[:channel_to_correct]

      unless parameters[:determine_correction] then

        return Correction.read_from_file(FileInteraction.correction_filename(parameters))

      end

      correction_x = []
      correction_y = []
      correction_z = []

      distance_cutoffs = MVector.zero(iobjs.size)
      
      #TODO

    end


    def apply_correction(c, iobjs)
      #TODO

    end


    def correct_single_object(c, iobj, ref_ch, corr_ch)
      #TODO

    end

    def generate_in_situ_correction
      #TODO

    end

    def apply_in_situ_correction(iobjs, corr_params)
      #TODO
    end

    def determine_tre(iobjs)
      #TODO
    end

  end

end

