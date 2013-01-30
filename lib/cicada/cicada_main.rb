#--
# /* ***** BEGIN LICENSE BLOCK *****
#  * 
#  * Copyright (c) 2012 Colin J. Fuller
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

require 'cicada/file_interaction'
require 'cicada/correction/correction'
require 'cicada/correction/position_corrector'
require 'cicada/fitting/p3d_fitter'
require 'ostruct'
require 'logger'


require 'rimageanalysistools'
require 'rimageanalysistools/image_shortcuts'
require 'rimageanalysistools/create_parameters'

require 'facets/math/sum'

require 'edu/stanford/cfuller/imageanalysistools/resources/common_methods'

java_import Java::edu.stanford.cfuller.imageanalysistools.filter.ImageSubtractionFilter
java_import Java::edu.stanford.cfuller.imageanalysistools.image.Histogram
java_import Java::edu.stanford.cfuller.imageanalysistools.fitting.GaussianImageObject
java_import Java::edu.stanford.cfuller.imageanalysistools.meta.parameters.ParameterDictionary

java_import Java::java.util.concurrent.Executors


module Cicada


  ##
  # This class is the main entry point for running 3D high-resolution colocalization and CICADA.
  #
  class CicadaMain

    include IATScripting #TODO: find a better way to get at these methods.

    # parameters required by the methods in this class
    REQUIRED_PARAMETERS = [:dirname, :basename, :im_border_size, :half_z_size, :determine_correction, :pixelsize_nm, :z_sectionsize_nm, :num_wavelengths, :photons_per_greylevel]

    # parmeters used but not required in this class or only required for optional functionality
    OPTIONAL_PARAMETERS = [:precomputed_position_data, :max_threads, :darkcurrent_image, :residual_cutoff, :max_greylevel_cutoff, :distance_cutoff, :fit_error_cutoff, :determine_correction, :determine_tre, :output_positions_to_directory, :in_situ_aberr_corr_basename, :in_situ_aberr_corr_channel, :log_to_file, :log_detailed_messages]

    attr_accessor :parameters, :failures, :logger

    ##
    # Sets up the analysis from a parameter dictionary.
    # 
    # @param [ParameterDictionary, Hash] p a parameter dictionary or other object with hash-like behavior
    #  containing all the parameters for the analysis.
    #
    def initialize(p)
      
      @parameters = p

      @parameters = RImageAnalysisTools.create_parameter_dictionary(p) unless @parameters.is_a? ParameterDictionary

      @failures = {r2: 0, edge: 0, sat: 0, sep: 0, err: 0}

      if @parameters[:darkcurrent_image] then

        @dark_image = FileInteraction.load_image(@parameters[:darkcurrent_image])

      end

      set_up_logging
      
    end

    
    ##
    # Load the position data from disk if this is requested in the specified parameters.  If this
    # has not been requested or if the position data file does not exist, returns nil.
    #
    # @return [Array<ImageObject>] the image objects, complete with their fitted positions, or nil if
    #   this should be recalculated or if the file cannot be found.
    #
    def load_position_data

      if @parameters[:precomputed_position_data] and FileInteraction.position_file_exists?(@parameters) then
        
        return FileInteraction.read_position_data(@parameters)

      end

      nil

    end


    ##
    # Loads the image and mask from an image and mask pair and darkcurrent corrects the 
    # image if specified in the parameters.
    # 
    # @param [OpenStruct, #image_fn, #mask_fn, #image=, #mask=] im_set  An object that
    #   specified the filename of image and mask and can store the loaded image 
    #   and mask.  Should respond to #image_fn, #mask_fn, #image=, and #mask= for
    #   getting the filenames and setting the loaded images, respectively.
    # @return [void]
    #
    def load_and_dark_correct_image(im_set)

      im_set.image = FileInteraction.load_image(im_set.image_fn)
      im_set.mask = FileInteraction.load_image(im_set.mask_fn)
      
      if (@dark_image) then

        im_set.image = im_set.image.writableInstance

        isf = ImageSubtractionFilter.new

        isf.setSubtractPlanarImage(true)

        isf.setReferenceImage(@dark_image)
        isf.apply(im_set.image)

      end
      
    end

    ##
    # Submits a single object to a thread queue for fitting.
    # 
    # @param [ImageObject] obj the image object to fit
    # @param [ExecutorService] queue the thread queue
    # 
    # @return [void]
    #
    def submit_single_object(obj, queue)

      queue.submit do 
        
          @logger.debug { "Processing object #{obj.getLabel}" }

          obj.fitPosition(@parameters)

      end

    end

    ##
    # Fits all the image objects in a single supplied image.
    #
    # Does not check whether the fitting was successful.
    # @param [OpenStruct, #image, #mask] im_set  An object that references the image
    #   and the mask from which the objects will be fit.  Should respond to #image and #mask.
    # @return [Array<ImageObject>] an array containing all the image objects in the image 
    #   (one per unique greylevel in the mask).
    #
    def fit_objects_in_single_image(im_set)

      objs = []

      load_and_dark_correct_image(im_set)

      unless im_set.image and im_set.mask then
        
        logger.error { "Unable to process image #{im_set.image_fn}." }

        return objs

      end

      h = Histogram.new(im_set.mask)

      max_threads = 1

      if @parameters[:max_threads] then
        max_threads = @parameters[:max_threads].to_i
      end

      thread_queue = Executors.newFixedThreadPool(max_threads)

      1.upto(h.getMaxValue) do |i|

        obj = GaussianImageObject.new(i, image_shallow_copy(im_set.mask), image_shallow_copy(im_set.image), ParameterDictionary.new(@parameters))

        obj.setImageID(im_set.image_fn)

        objs << obj

      end

      objs.each do |obj|

        submit_single_object(obj, thread_queue)

      end

      thread_queue.shutdown

      until thread_queue.isTerminated do
        sleep 0.4
      end

      objs

    end


    ##
    # Checks whether the fitting was successful for a given object according to several criteria: 
    # whether the fitting finished without error, whether the R^2 value of the fit is above the
    # cutoff, whether the object is too close to the image edges, whether the camera is saturated
    # in the object, whether the separation between channels is above some cutoff, and whether the
    # calculated fitting error is too large.  Cutoffs for all these criteria are specified in the
    # parameters file.
    #
    # @param [ImageObject] to_check the ImageObject to check for fitting success
    # @return [Boolean] whether the fitting was successful by all criteria.
    #
    def check_fit(to_check)

      checks = [:check_r2, :check_edges, :check_saturation, :check_separation, :check_error]

      to_check.finishedFitting and checks.all? { |c| self.send(c, to_check) }

    end

    
    ##
    # Checks whether the fit R^2 value is below the specified cutoff.
    #
    # @param (see #check_fit)
    # @return [Boolean] whether the fitting was successful by this criterion.
    #
    def check_r2(to_check)

      return true unless @parameters[:residual_cutoff]

      to_check.getFitR2ByChannel.each do |r2|

        if r2 < @parameters[:residual_cutoff].to_f then
          
          @failures[:r2] += 1

          @logger.debug { "check failed for object #{to_check.getLabel} R^2 = #{r2}" }

          return false

        end

      end

      true

    end

    ##
    # Checks whether the fitted position is too close to the image edges.
    # @param (see #check_fit)
    # @return (see #check_r2)
    #
    def check_edges(to_check)

      eps = 0.1

      border_size = @parameters[:im_border_size].to_f
      z_size = @parameters[:half_z_size].to_f

      range_x = border_size...(to_check.getParent.getDimensionSizes[:x] - border_size)
      range_y = border_size...(to_check.getParent.getDimensionSizes[:y] - border_size)
      range_z = z_size...(to_check.getParent.getDimensionSizes[:z] - z_size)

      to_check.getFitParametersByChannel.each do |fp|
        
        x = fp.getPosition(ImageCoordinate::X)
        y = fp.getPosition(ImageCoordinate::Y)
        z = fp.getPosition(ImageCoordinate::Z)

        ok = (range_x.include?(x) and range_y.include?(y) and range_z.include?(z))

        unless ok then
          
          @failures[:edge] += 1

          @logger.debug { "check failed for object #{to_check.getLabel} position: #{x}, #{y}, #{z}" }

          return false

        end

      end

      true

    end


    ##
    # Checks whether the camera has saturated in the object.
    # @param (see #check_fit)
    # @return (see #check_r2)
    #
    def check_saturation(to_check)

      if @parameters[:max_greylevel_cutoff] then

        to_check.boxImages

        cutoff = @parameters[:max_greylevel_cutoff].to_f

        to_check.getParent.each do |ic|

          if to_check.getParent[ic] > cutoff then 

            to_check.unboxImages
            @failures[:sat] += 1

            @logger.debug { "check failed for object #{to_check.getLabel} greylevel: #{to_check.getParent[ic]}" }

            return false 

          end

        end

      end
        
      true

    end

    ##
    # Checks whether the separation between channels is too large.
    #
    # Note that this check can significantly skew the distance measurements if the cutoff is too small.
    # This remains here because occasionally closely spaced objects are fit as a single object and produce
    # ridiculous values.
    #
    # @param (see #check_fit)
    # @return (see #check_r2)
    #
    def check_separation(to_check)

      if @parameters[:distance_cutoff] then

        size_c = to_check.getFitParametersByChannel.size

        xy_pixelsize_2 = @parameters[:pixelsize_nm].to_f**2

        z_sectionsize_2 = @parameters[:z_sectionsize_nm].to_f**2

        0.upto(size_c-1) do |ci|
          0.upto(size_c-1) do |cj|

            fp1 = to_check.getFitParametersByChannel.get(ci)
            fp2 = to_check.getFitParametersByChannel.get(cj)

            ijdist = xy_pixelsize_2 * (fp1.getPosition(ImageCoordinate::X) - fp2.getPosition(ImageCoordinate::X))**2 +
              xy_pixelsize_2 * (fp1.getPosition(ImageCoordinate::Y) - fp2.getPosition(ImageCoordinate::Y))**2 +
              z_sectionsize_2 * (fp1.getPosition(ImageCoordinate::Z) - fp2.getPosition(ImageCoordinate::Z))**2

            ijdist = ijdist**0.5

            if (ijdist > @parameters[:distance_cutoff].to_f) then
              
              @failures[:sep] += 1
              @logger.debug { "check failed for object #{to_check.getLabel} with distance: #{ijdist}" } 

              return false              

            end

          end
        end

      end

      true

    end


    ##
    # Checks whether the caluclated fitting error (summed in quadrature over all wavelengths)
    # is larger than a specified cutoff.
    # 
    # @param (see #check_fit)
    # @return (see #check_r2)
    #
    def check_error(to_check)

      if @parameters[:fit_error_cutoff] then

        total_error = 0

        to_check.getFitErrorByChannel.each do |d|

          total_error += d**2

        end

        total_error = total_error**0.5

        if total_error > @parameters[:fit_error_cutoff].to_f or total_error.nan? then

          @failures[:err] += 1

          @logger.debug { "check failed for object #{to_check.getLabel} with total fitting error: #{total_error}" }

          return false

        end

      end

      true

    end

    ##
    # Sets up a logger to either standard output or a file with appropriate detail level
    # as specified in the parameters
    #
    # @return (void)
    #
    def set_up_logging

      if @parameters[:log_to_file] then

        @logger = Logger.new(@parameters[:log_to_file])

      else

        @logger = Logger.new(STDOUT)

      end

      if @parameters[:log_detailed_messages] then
        
        @logger.sev_threshold = Logger::DEBUG

      else

        @logger.sev_threshold = Logger::INFO

      end

    end

    ##
    # Loads previously existing image objects for the current images or fits them anew
    # if they don't exist or this is requested in the parameters.
    #
    # @return [Array<ImageObject>] The image objects that have been loaded or fit.  Only
    #   successfully fit objects that have passed all checks are included.
    #
    def load_or_fit_image_objects

      image_objects = load_position_data

      unless image_objects then

        image_objects = []

        to_process = FileInteraction.list_files(@parameters)

        to_process.each do |im_set|
          
          objs = fit_objects_in_single_image(im_set)

          objs.each do |o|
            
            if check_fit(o) then

              image_objects << o

            end

            o.nullifyImages

          end

        end

        @logger.info { "fitting failures by type: #{@failures.to_s}" }
        
      end

      image_objects

    end

    ##
    # Runs the analysis.
    #
    # @return [void]
    #
    def go

      image_objects = load_or_fit_image_objects
      
      FileInteraction.write_position_data(image_objects, @parameters)

      pc = PositionCorrector.new(@parameters)

      c = pc.generate_correction(image_objects)

      tre = 0.0

      if @parameters[:determine_tre] and @parameters[:determine_correction] then
        
        puts "calculating tre"
        
        tre = pc.determine_tre(image_objects)

        c.tre= tre

      else

        tre = c.tre

      end

      
      c.write_to_file(FileInteraction.correction_filename(@parameters))

      

      diffs = pc.apply_correction(c, image_objects)

      corrected_image_objects = []

      image_objects.each do |iobj|

        if iobj.getCorrectionSuccessful then
          
          corrected_image_objects << iobj

        end

      end

      FileInteraction.write_position_data(corrected_image_objects, @parameters)

      
      image_objects = corrected_image_objects

      df= P3DFitter.new(@parameters)

      fitparams = df.fit(image_objects, diffs)

      @logger.info { "p3d fit parameters: #{fitparams.join(', ')}" }

      if @parameters[:in_situ_aberr_corr_basename] and @parameters[:in_situ_aberr_corr_channel] then

        slopes = pc.determine_in_situ_aberration_correction

        vector_diffs = pc.apply_in_situ_aberration_correction(image_objects, slopes)

        scalar_diffs = get_scalar_diffs_from_vector(vector_diffs)

        corr_fit_params = df.fit(image_objects, scalar_diffs)

        FileInteraction.write_differences(diffs, @parameters)

        if corr_fit_params then

          @logger.info { "p3d fit parameters after in situ correction: #{fitparams.join(', ') }" }
                
        else

          @logger.info { "unable to fit after in situ correction" } 

        end

      end

    end

    ##
    # Converts an array of vectors to an array of scalars by taking their 2-norm.
    # 
    # @param [Enumerable< Enumerable<Numeric> >] vector_diffs an array of arrays (vectors, etc.) 
    #  each of which will be normed.
    #
    # @return [Array] an array of the norms of the vectors provided.
    #
    def get_scalar_diffs_from_vector(vector_diffs)

      vector_diffs.map do |vd|

        Math.sqrt(Math.sum(vd) { |e| e**2 })

      end

    end

    ##
    # Runs analysis using a specified parameter file.
    #
    # @param [String] fn  the filename of the parameter file
    #
    # @return [void]
    #
    def self.run_from_parameter_file(fn)

      java_import Java::edu.stanford.cfuller.imageanalysistools.meta.AnalysisMetadataParserFactory

      parser = AnalysisMetadataParserFactory.createParserForFile(fn)

      p = parser.parseFileToParameterDictionary(fn)

      c = new(p)

      c.go

    end
      
    
  end

end

##
# If this file is run from the command line, start the analysis using the parameter file
# specified on the command line.
#
if __FILE__ == $0 then

  Cicada::CicadaMain.run_from_parameter_file(ARGV[0])

end






