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
require 'ostruct'
require 'logger'


require 'rimageanalysistools'
require 'rimageanalysistools/thread_queue'
require 'rimageanalysistools/image_shortcuts'

java_import Java::edu.stanford.cfuller.imageanalysistools.filter.ImageSubtractionFilter
java_import Java::edu.stanford.cfuller.imageanalysistools.image.Histogram
java_import Java::edu.stanford.cfuller.imageanalysistools.fitting.


module Cicada

  class Cicada

    REQUIRED_PARAMETERS = [:dirname, :basename, :im_border_size, :half_z_size, :determine_correction, :pixelsize_nm, :z_sectionsize_nm]

    OPTIONAL_PARAMETERS = [:precomputed_position_data, :max_threads, :darkcurrent_image, :residual_cutoff, :max_greylevel_cutoff, :distance_cutoff, :fit_error_cutoff, :determine_correction, :determine_tre, :output_positions_to_directory, :in_situ_aberr_corr_basename, :in_situ_aberr_corr_channel, :log_to_file, :log_detailed_messages]

    attr_accessor :parameters, :failures, :logger

    def load_position_data

      if @parameters[:precomputed_position_data] and FileInteraction.position_file_exists?(@parameters) then
        
        return FileInteraction.read_position_data(@parameters)

      end

      nil

    end


    def load_and_dark_correct_image(im_set)

      im_set.image = FileInteraction.load_image(im_set.image_fn)
      im_set.mask = FileInteraction.load_image(im_set.mask_fn)
      
      if (@dark_image) then

        isf = ImageSubtractionFilter.new

        isf.setSubtractPlanarImage(true)

        isf.setReferenceImage(@dark_image)
        isf.apply(im_set.image)

      end
      
    end


    def fit_objects_in_single_image(im_set)

      objs = []

      load_and_dark_correct_image(im_set)

      unless im_set.image and im_set.mask then
        
        logger.error { "Unable to process image #{im_set.image_fn}." }

        return objs

      end

      h = Histogram.new(im_set.mask)

      thread_queue = RImageAnalysisTools::ThreadQueue.new

      if @parameters[:max_threads] then
        thread_queue.max_therads = @parameters[:max_threads]
      end

      0.upto(h.getMaxValue) do |i|

        obj = GaussianImageObject.new(i, image_shallow_copy(im_set.mask), image_shallow_copy(im_set.image), @parameters)

        obj.setImageID(im_set.image_fn)

        objs << obj

        thread_queue.enqueue do

          @logger.debug { "Processing object #{i}" }

          obj.fitPosition(@parameters)

        end

      end


      thread_queue.finish

      objs


    end


    def check_fit(to_check)

      to_check.finishedFitting and check_r2(to_check) and check_edges(to_check) and check_saturation(to_check) and check_separation(to_check) and check_error(to_check)

    end

    def check_r2(to_check)

      return true unless @parameters[:residual_cutoff]

      obj.getFitR2ByChannel.each do |r2|

        if r2 < @parameters[:residual_cutoff].to_f then
          
          @failures[:r2] += 1

          @logger.debug { "check failed for object #{to_check.getLabel} R^2 = #{r2}" }

          return false

        end

      end

      true

    end

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






    
    def check_saturation(to_check)

      if @parameters[:max_greylevel_cutoff] then

        to_check.boxImages

        cutoff = @parameters[:max_greylevel_cutoff].to_f

        to_check.getParent.each do |ic|

          if getParent[ic] > cutoff then 

            to_check.unboxImages
            @failures[:sat] += 1

            @logger.debug { "check failed for object #{to_check.getLabel} greylevel: #{to_check[ic]}" }

            return false 

          end

        end

      end
        
      true

    end


    def check_separation(to_check)

      if @parameters[:distance_cutoff] then

        size_c = to_check.getFitParametersByChannel.size

        xy_pixelsize_2 = @parameters[:pixelsize_nm].to_f**2

        z_sectionsize_2 = @parameters[:z_sectionsize_nm].to_f**2

        0.upto(size_c) do |ci|
          0.upto(size_c) do |cj|

            fp1 = to_check.getFitParametersByChannel.get(i)
            fp2 = to_check.getFitParametersByChannel.get(j)

            ijdist = xy_pixelsize_2 * (fp1.getPosition(ImageCoordinate::X) - fp2.getPosition(ImageCoordinate:::X))**2 +
              xy_pixelsize_2 * (fp1.getPosition(ImageCoordinate::Y) - fp2.getPosition(ImageCoordinate:::Y))**2 +
              z_sectionsize_2 * (fp1.getPosition(ImageCoordinate::Z) - fp2.getPosition(ImageCoordinate:::Z))**2

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


    def set_up_logging

      if @parameters[:log_to_file] then

        @logger = Logger.new(@parameters[:log_to_file])

      else

        @logger = Logger.new(STDOUT)

      end

      if @parameters[:log_detailed_messages] then
        
        @logger.sev_threshold = Logger::INFO

      else

        @logger.sev_threshold = Logger::DEBUG

      end

    end

    def initialize(p)
      
      @parameters = p

      @failures = {r2: 0, edge: 0, sat: 0, sep: 0, err: 0}

      if @parameters[:darkcurrent_image] then

        @dark_image = FileInteraction.load_image(@parameters[:darkcurrent_image])

      end

      set_up_logging
      
    end

    def load_or_fit_image_objects

      image_objects = load_position_data

      unless image_objects then

        image_objects = []

        to_process = FileInteraction.list_files

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

    def go(p)

      initialize(p)

      image_objects = load_or_fit_image_objects
      
      FileInteraction.write_position_data(image_objects, @parameters)

      pc = PositionCorrector.new(@parameters)

      c = pc.get_correction(image_objects)

      tre = 0.0

      if @parameters[:determine_tre] and @parameters[:determine_correction] then
        
        tre = pc.determine_tre(image_objects)

        c.tre= tre

      else

        tre = c.tre

      end

      
      c.write(FileInteraction.correction_filename)

      

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

      end

      if corr_fit_params then

        @logger.info { "p3d fit parameters after in situ correction: #{fitparams.join(', ') }" }

      else

        @logger.info { "unable to fit after in situ correction" } 

      end


    end

    def get_scalar_diffs_from_vector(vector_diffs)

      vector_diffs.map do |vd|

        Math.sqrt(vd.reduce(0.0) { |a,e| a + e**2 })

      end

   end
      


    
  end

end








