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
require 'cicada/correction/in_situ_correction'

require 'ostruct'
require 'logger'

require 'pqueue'
require 'facets/enumerable/ewise'
require 'facets/math/mean'
require 'rimageanalysistools/fitting/bisquare_linear_fit'
require 'rimageanalysistools/thread_queue'

java_import Java::org.apache.commons.math3.linear.ArrayRealVector
java_import Java::java.util.concurrent.Executors

module Cicada

  ##
  # Generates and applies aberration corrections.  Used both for standard 3d 
  # high-resolution colocalization corrections and in-situ corrections.
  #
  class PositionCorrector

    # parameters required by the methods in this class
    REQUIRED_PARAMETERS = [:pixelsize_nm, :z_sectionsize_nm, :num_points, :reference_channel, :channel_to_correct]

    # parmeters used but not required in this class or only required for optional functionality
    OPTIONAL_PARAMETERS = [:determine_correction, :max_threads, :in_situ_aberr_corr_channel, :inverted_z_axis, :disable_in_situ_corr_constant_offset]

    # Number of parameters used for correction (6, as this is the number of parameters 
    # for a 2d quadratic fit)
    NUM_CORR_PARAM = 6

    attr_accessor :parameters, :pixel_to_distance_conversions, :logger

    ##
    # Constructs a new position corrector with the specified parameters
    #
    # @param [ParameterDictionary, Hash] p a hash-like object containing the analysis parameters
    #
    def initialize(p)
      @parameters = p
      @pixel_to_distance_conversions = Vector[p[:pixelsize_nm].to_f, p[:pixelsize_nm].to_f, p[:z_sectionsize_nm].to_f]
      @logger = Logger.new(STDOUT)
    end

    ##
    # Creates a RealVector (org.apache.commons.math3.linear.RealVector) that is a copy of
    # the contents of the supplied vector.
    #
    # @param [Vector] vec the Vector to convert
    #
    # @return [RealVector] the commons math RealVector containing the same elements
    #
    def self.convert_to_realvector(vec)
      conv = ArrayRealVector.new(vec.size, 0.0)
      vec.each_with_index do |e, i|
        conv.setEntry(i, e)
      end
      conv
    end

    ##
    # Generates a correction from a specified array of image objects.
    #
    # @param [Array<ImageObject>] iobjs the image objects to be used for the correction
    #
    # @return [Correction] the correction generated from the input objects
    #
    def generate_correction(iobjs)
      #TODO refactor into smaller chunks
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
        np = @parameters[:num_points].to_i

        distances_to_objects.each do |d|
          if pq.size < np + 1 then
            pq.push d
          elsif d < pq.top then
            pq.pop
            pq.push d
          end
        end

        first_exclude = pq.pop
        last_dist = pq.pop
        distance_cutoff = (last_dist + first_exclude)/2.0
        distance_cutoffs[ind] = distance_cutoff

        objs_ind_to_fit = (0...iobjs.size).select { |i| distances_to_objects[i] < distance_cutoff }
        objs_to_fit = iobjs.values_at(*objs_ind_to_fit)

        diffs_to_fit = MMatrix[*objs_to_fit.map { |e| e.getVectorDifferenceBetweenChannels(ref_ch, corr_ch).toArray }]
        x_to_fit = objs_to_fit.map { |e| e.getPositionForChannel(ref_ch).getEntry(0) }
        y_to_fit = objs_to_fit.map { |e| e.getPositionForChannel(ref_ch).getEntry(1) }
        x = Vector[*x_to_fit.map { |e| e - obj_pos.getEntry(0) }]
        y = Vector[*y_to_fit.map { |e| e - obj_pos.getEntry(1) }]

        correction_parameters = Matrix.columns([MVector.unit(objs_to_fit.size), x, y, x.map { |e| e**2 }, y.map { |e| e**2 }, x.map2(y) { |ex, ey| ex*ey }])
        cpt = correction_parameters.transpose
        cpt_cp = cpt * correction_parameters
        cpt_cp_lup = cpt_cp.lup

        correction_x << cpt_cp_lup.solve(cpt * diffs_to_fit.column(0))
        correction_y << cpt_cp_lup.solve(cpt * diffs_to_fit.column(1))
        correction_z << cpt_cp_lup.solve(cpt * diffs_to_fit.column(2))
      end

      Correction.new(correction_x, correction_y, correction_z, distance_cutoffs, iobjs, ref_ch, corr_ch)
    end

    ##
    # Changes the scale of a vector from image units to physical distances using distance specified
    # in the analysis parameters.
    #
    # @param [Vector] vec the vector to scale
    # 
    # @return [Vector] the vector scaled to physical units (by parameter naming convention, in nm)
    #
    def apply_scale(vec)
      vec.map2(@pixel_to_distance_conversions) { |e1, e2| e1*e2 }
    end

    ##
    # Corrects an array of image objects using the provided correction.
    #
    # @param [Correction] c the correction to be used
    # @param [Array<ImageObject>] iobjs the image objects to be corrected.
    # 
    # @return [Array<Numeric>] the corrected scalar difference between
    #  wavelengths for each image object provided.
    #
    def apply_correction(c, iobjs)
      ref_ch = @parameters[:reference_channel].to_i
      corr_ch = @parameters[:channel_to_correct].to_i
      vec_diffs = iobjs.map { |e| e.getVectorDifferenceBetweenChannels(ref_ch, corr_ch) }
      vec_diffs.map! { |e| apply_scale(Vector[*e.toArray]) }
      corrected_vec_diffs = []

      if c.nil? then
        corrected_vec_diffs = vec_diffs
      else
        iobjs.each do |iobj|
          begin
            corrected_vec_diffs << correct_single_object(c, iobj, ref_ch, corr_ch)
            iobj.setCorrectionSuccessful(true)
          rescue UnableToCorrectError => e
            iobj.setCorrectionSuccessful(false)
          end
        end
        corrected_vec_diffs.map! { |e| apply_scale(e) }    
      end
  
      print_distance_components(vec_diffs, corrected_vec_diffs)
      corrected_vec_diffs.map { |e| e.norm  } 
    end

    ##
    # Prints the mean scalar and vector differences both corrected and uncorrected.
    #
    # @param [Array<Vector>] vec_diffs an array of the uncorrected vector differences
    # @param [Array<Vector>] corrected_vec_diffs an array of the corrected vector differences
    #
    # @return [void]
    #
    def print_distance_components(vec_diffs, corrected_vec_diffs)
      mean_uncorr_vec = [0.0, 0.0, 0.0] 
      vec_diffs.each do |e|
        mean_uncorr_vec = mean_uncorr_vec.ewise + e.to_a
      end

      mean_corr_vec = [0.0, 0.0, 0.0]
      corrected_vec_diffs.each do |e|
        mean_corr_vec = mean_corr_vec.ewise + e.to_a
      end

      mean_uncorr_vec.map! { |e| e / vec_diffs.length }
      mean_corr_vec.map! { |e| e / corrected_vec_diffs.length }

      self.logger.info("mean components uncorrected: [#{mean_uncorr_vec.join(', ')}]")
      self.logger.info("mean distance uncorrected: #{Vector[*mean_uncorr_vec].norm}")
      self.logger.info("mean components corrected: [#{mean_corr_vec.join(', ')}]")
      self.logger.info("mean distance corrected: #{Vector[*mean_corr_vec].norm}")
    end

    ##
    # Corrects a single image object for the two specified channels.
    #
    # @param [Correction] c the correction to be used
    # @param [ImageObject] iobj the object being corrected
    # @param [Integer] ref_ch the reference channel relative to which the other will be corrected
    # @param [Integer] corr_ch the channel being corrected
    #
    # @return [Vector] the corrected (x,y,z) vector difference between the two channels
    #
    def correct_single_object(c, iobj, ref_ch, corr_ch)
      corr = c.correct_position(iobj.getPositionForChannel(ref_ch).getEntry(0), iobj.getPositionForChannel(corr_ch).getEntry(1))
      if parameters[:invert_z_axis] then
        corr.setEntry(2, -1.0*corr.getEntry(2))
      end

      iobj.applyCorrectionVectorToChannel(corr_ch, PositionCorrector.convert_to_realvector(corr))
      Vector.elements(iobj.getCorrectedVectorDifferenceBetweenChannels(ref_ch, corr_ch).toArray)
    end

    ##
    # Generates an in situ aberration correction (using the data specified in a parameter file)
    #
    # @return @see #generate_in_situ_correction_from_iobjs
    #
    def generate_in_situ_correction
      iobjs_for_in_situ_corr = FileInteraction.read_in_situ_corr_data(@parameters)
      generate_in_situ_correction_from_iobjs(iobjs_for_in_situ_corr)
    end

    ##
    # Generates an in situ aberration correction from the supplied image objects.
    #
    # @param [Array<ImageObject>] an array containing the image objects from which the in situ
    #  correction will be generated
    #
    # @return [InSituCorrection] an InSituCorrection object containing the necessary information
    #  to perform the correction.
    #
    def generate_in_situ_correction_from_iobjs(iobjs_for_in_situ_corr)
      ref_ch = @parameters[:reference_channel].to_i
      corr_ch = @parameters[:channel_to_correct].to_i
      cicada_ch = @parameters[:in_situ_aberr_corr_channel]

      InSituCorrection.new(ref_ch, cicada_ch, corr_ch, iobjs_for_in_situ_corr, @parameters[:disable_in_situ_corr_constant_offset])
    end

    ##
    # Applies an in situ aberration correction to an array of image objects.
    #
    # @param [Enumerable<ImageObject>] iobjs the objects to be corrected
    # @param [InSituCorrection] isc the in situ correction object.
    #
    # @return [Array< Array <Numeric> >] an array of the corrected vector distance between
    #  wavelengths for each image object being corrected.
    #
    def apply_in_situ_correction(iobjs, isc)
      isc.apply(iobjs)
    end

    ##
    # Caluclates the target registration error (TRE) for an array of image objects
    # to be used for correction.
    #
    # @param [Enumerable<ImageObject>] iobjs the objects whose TRE will be calculated
    # 
    # @return [Float] the (3d) TRE
    #
    def determine_tre(iobjs)
      ref_ch = @parameters[:reference_channel].to_i
      corr_ch = @parameters[:channel_to_correct].to_i
      results = []
      max_threads = 1
      if @parameters[:max_threads]
        max_threads = @parameters[:max_threads].to_i
      end

      tq = Executors.newFixedThreadPool(max_threads)
      mut = Mutex.new

      iobjs.each_with_index do |iobj, i|
        RImageAnalysisTools::ThreadQueue.new_scope_with_vars(iobj, iobjs, i) do |obj, objs, ii|
          tq.submit do 
            self.logger.debug("Calculating TRE.  Progress: #{ii} of #{objs.length}") if ii.modulo(10) == 0
            temp_objs = objs.select { |e| e != obj }
            c = generate_correction(temp_objs)
            pos = obj.getPositionForChannel(ref_ch)
            result = OpenStruct.new
            begin
              corr = c.correct_position(pos.getEntry(0), pos.getEntry(1))
              result.success = true
              tre_vec = Vector[*obj.getVectorDifferenceBetweenChannels(ref_ch, corr_ch).toArray] - corr
              tre_vec = tre_vec.map2(@pixel_to_distance_conversions) { |e1, e2| e1*e2 }
              result.tre = tre_vec.norm
              result.tre_xy = Math.hypot(tre_vec[0], tre_vec[1])
            rescue UnableToCorrectError => e
              result.success = false
            end

            mut.synchronize do
              results << result
            end

            result
          end
        end
      end

      tq.shutdown
      until tq.isTerminated do
        sleep 0.4
      end

      tre_values = results
      tre_values.select! { |e| e.success }
      tre_3d = Math.mean(tre_values) { |e| e.tre }
      tre_2d = Math.mean(tre_values) { |e| e.tre_xy }
      self.logger.info("TRE: #{tre_3d}")
      self.logger.info("X-Y TRE: #{tre_2d}")

      tre_3d
    end
  end
end
