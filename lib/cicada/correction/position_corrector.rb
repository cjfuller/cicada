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

require 'ostruct'

require 'pqueue'

require 'facets/enumerable/ewise'
require 'facets/math/mean'

require 'rimageanalysistools/fitting/biquare_linear_fit'

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
      
      ref_ch = parameters[:reference_channel].to_i
      corr_ch = parameters[:channel_to_correct].to_i

      unless parameters[:determine_correction] then

        return Correction.read_from_file(FileInteraction.correction_filename(parameters))

      end

      correction_x = []
      correction_y = []
      correction_z = []

      distance_cutoffs = MVector.zero(iobjs.size)

      iobjs.each_with_index do |obj, ind|

        obj_pos = obj.getPositionForChannel(ref_ch)
        
        distances_to_objects = iobjs.map { |obj2| obj2.getPositionForChannel(ref_ch).subtract(obj_pos).getNorm }
        
        pq = PQueue.new

        0.upto(@parameters[:num_points].to_i) do |i|

          pq.push(distances_to_objects[i])

        end

        (@parameters[:num_points].to_i + 1).upto(distances_to_objects.size - 1) do |i|

          if distances_to_objects[i] < pq.top then

            pq.pop

            pq.push(distances_to_objects[i])

          end

        end

        first_exclude = pq.pop

        last_dist = pq.pop

        distance_cutoff = (last_dist + first_exclude)/2.0

        distance_cutoffs[ind] = distance_cutoff

        objs_ind_to_fit = (0...iobjs.size).select { |i| distances_to_objects[i] < distance_cutoff }
                
        objs_to_fit = iobjs.values_at(*objs_ind_to_fit)

        diffs_to_fit = MMatrix[objs_to_fit.map { |e| e.getVectorDifferencesBetweenChannels(ref_ch, corr_ch) }]
        x = Vector[objs_to_fit.map { |e| e.getPositionForChannel(ref_ch).getEntry(0) }]
        y = Vector[objs_to_fit.map { |e| e.getPositionForChannel(ref_ch).getEntry(1) }]
        
        correction_parameters = Matrix.columns([MVector.unit(iobjs.size), x, y, x.map { |e| e**2 }, y.map { |e| e**2 }, x.map2(y) { |ex, ey| ex*ey }])

        corr_param_lup = correction_parameters.lup

        correction_x << corr_param_lup.solve(diffs_to_fit.column(0))
        correction_y << corr_param_lup.solve(diffs_to_fit.column(1))
        correction_z << corr_param_lup.solve(diffs_to_fit.column(2))
     
      end

      Correction.new(correction_x, correction_y, correction_z, distance_cutoffs, iobjs, ref_ch, corr_ch)

    end


    def apply_correction(c, iobjs)
     
      ref_ch = @parameters[:reference_channel].to_i
      corr_ch = @parameters[:channel_to_correct].to_i

      vec_diffs = iobjs.map { |e| e.getScalarDifferenceBetweenChannels(ref_ch, corr_ch) }

      corrected_vec_diffs = []

      if @parameters[:correct_images] then

        iobjs.each do |iobj|

          begin

            corrected_vec_diffs << correct_single_object(c, iobj, ref_ch, corr_ch)

            iobj.setCorrectionSuccessful(true)

          rescue UnableToCorrectError => e

            iobj.setCorrectionSuccessful(false)

          end

        end

      end 
      
      print_distance_components(vec_diffs, corrected_vec_diffs)

      corrected_vec_diffs.map { |e| Vector[*e].norm ) } 

    end

    def print_distance_components(vec_diffs, corrected_vec_diffs)

      mean_uncorr_vec = [0.0, 0.0, 0.0] 

      vec_diffs.each do |e|

        mean_uncorr_vec = mean_uncorr_vec.ewise + e

      end

      mean_corr_vec = [0.0, 0.0, 0.0]

      corrected_vec_diffs.each do |e|

        mean_corr_vec = mean_corr_vec.ewise + e

      end

      #TODO - logging

      puts "mean components uncorrected: [#{mean_uncorr_vec.join(', ')}]"
      puts "mean distance uncorrected: #{Vector[*mean_uncorr_vec].norm}"
      puts "mean components corrected: [#{mean_corr_vec.join(', ')}]"
      puts "mean distance corrected: #{Vector[*mean_corr_vec].norm}"

    end

    def correct_single_object(c, iobj, ref_ch, corr_ch)
      
      corr = c.correct_position(iobj.getPositionForChannel(ref_ch).getEntry(0), iobj.getPositionForChannel(corr_ch).getEntry(1))

      if parameters[:invert_z_axis] then

        corr.setEntry(2, -1.0*corr.getEntry(2))

      end

      iobj.applyCorrectionVectorToChannel(corr_ch, corr)
      
      iobj.getCorrectedVectorDifferenceBetweenChannels(ref_ch, corr_ch)

    end

    def generate_in_situ_correction
      
      ref_ch = @parameters[:reference_channel].to_i
      corr_ch = @parameters[:channel_to_correct].to_i
      cicada_ch = @parameters[:in_situ_aberr_corr_channel]

      iobjs_for_in_situ_corr = FileInteraction.read_in_situ_corr_data(@parameters)

      corr_diffs = Matrix.rows(iobjs_for_in_situ_corr.map { |iobj| iobj.getCorrectedVectorDifferenceBetweenChannels(ref_ch, cicada_ch) })
      expt_diffs = Matrix.rows(iobjs_for_in_situ_corr.map { |iobj| iobj.getCorrectedVectorDifferenceBetweenChannels(ref_ch, corr_ch) })

      bslf = BisquareLinearFit.new

      bslf.disableIntercept if @parameters[:disable_in_situ_corr_constant_offset]

      all_parameters = 0.upto(corr_diffs.column_size - 1).collect do |i|

        bslf.fit_rb(corr_diffs.column(i), expt_diffs.column(i))

      end
     
      all_parameters

    end

    def apply_in_situ_correction(iobjs, corr_params)

      corr_params = corr_params.transpose

      ref_ch = @parameters[:reference_channel].to_i
      corr_ch = @parameters[:channel_to_correct].to_i
      cicada_ch = @parameters[:in_situ_aberr_corr_channel]

      corrected_differences = iobjs.map do |iobj|
        
        corr_diff = iobj.getCorrectedVectorDifferenceBetweenChannels(ref_ch, cicada_ch)
        expt_diff = iobj.getCorrectedVectorDifferenceBetweenChannels(ref_ch, corr_ch)

        correction = (corr_diff.ewise * corr_params[0]).ewise + corr_params[1]

        expt_diff.ewise - correction

      end

      corrected_differences
          
    end

    def determine_tre(iobjs)
      
      ref_ch = @parameters[:reference_channel].to_i
      corr_ch = @parameters[:channel_to_correct].to_i

      threads = []

      iobjs.each do |iobj|

        threads << Thread.new(iobj, iobjs) do |obj, objs|

          temp_objs = objs.select { |e| e != obj }

          c = generate_correction(temp_objs)

          pos = obj,getPositionForChannel(ref_ch)

          result = OpenStruct.new

          begin
            
            corr = c.correct_position(pos.getEntry(0), pos.getEntry(1))

            result.success = true

            tre_vec = obj.getVectorDifferenceBetweenChannels(ref_ch, corr_ch).ewise - corr

            tre_vec = tre_vec.ewise * pixel_to_distance_conversions

            result.tre = Vector[*tre_vec].norm

            result.tre_xy = Math.hypot(tre_vec[0], tre_vec[1])

          rescue UnableToCorrectError => e

            result.success = false

          end

          result

        end

      end

      tre_values = threads.map { |t| t.value }

      tre_values.select! { |e| e.success }

      tre_3d = Math.mean(tre_values) { |e| e.tre }
      
      tre_2d = Math.mean(tre_values) { |e| e.tre_xy }

      #TODO logging

      puts "TRE: #{tre_3d}"
      puts "X-Y TRE: #{tre_2d}"

      tre_3d

    end

  end

end

