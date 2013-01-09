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

require 'rexml/document'
require 'ostruct'
require 'cicada/mutable_matrix'

module Cicada

  ##
  # An error indicating that a position cannot be corrected (probably due to incomplete
  # coverage in the correction dataset).
  class UnableToCorrectError < StandardError; end

  ##
  # Stores data for a standard 3d high-resolution colocalization correction, including
  # positions for a number of objects used for correction, and local quadratic fits of
  # aberration near these objects.  Can correct 2d positions based upon this data.
  # 
  class Correction
    
    # Strings used in XML elements and attributes when writing a correction to an XML format
    XML_STRINGS = { correction_element: "correction",
      correction_point_element: "point", 
      n_points_attr: "n",
      ref_channel_attr: "reference_channel",
      corr_channel_attr: "correction_channel",
      x_pos_attr: "x_position",
      y_pos_attr: "y_position",
      z_pos_attr: "z_position",
      x_param_element: "x_dimension_parameters",
      y_param_element: "y_dimension_parameters",
      z_param_element: "z_dimension_parameters",
      binary_data_element: "serialized_form",
      encoding_attr: "encoding",
      encoding_name: "base64"}

    # Number of parameters used for correction (6, as this is the number of parameters 
    # for a 2d quadratic fit)
    NUM_CORR_PARAM = 6

    attr_accessor :tre, :correction_x, :correction_y, :correction_z, :reference_channel, :correction_channel, :positions_for_correction, :distance_cutoffs

    ##
    # Constructs a new correction based on the supplied data 
    #
    # @param [Array<MVector>] c_x an array of mutable vectors each of which contains the parameters for
    #  the interpolating function centered at an image object used for correction in the x direction
    # @param [Array<MVector>] c_y an array of mutable vectors each of which contains the parameters for
    #  the interpolating function centered at an image object used for correction in the y direction
    # @param [Array<MVector>] c_z an array of mutable vectors each of which contains the parameters for
    #  the interpolating function centered at an image object used for correction in the z direction
    # @param [MVector] distance_cutoffs a mutable vector containing the distance to the farthest point
    #  used to generate the interpolating function for each image object
    # @param [Array<ImageObject>] image_objects the image objects used for correction
    # @param [Integer] reference_channel  the reference channel relative to which others are corrected
    # @param [Integer] correction_channel the channel being corrected
    #
    def initialize(c_x, c_y, c_z, distance_cutoffs, image_objects, reference_channel, correction_channel)

      @correction_x = c_x
      @correction_y = c_y
      @correction_z = c_z
      @reference_channel = reference_channel
      @correction_channel = correction_channel
      @distance_cutoffs = distance_cutoffs

      @positions_for_correction = MMatrix.build do |r, c|

        image_objects[r].getPositionForChannel(reference_chanel)[c]

      end

    end

    ##
    # Writes the correction to a specified file in XML format.
    # 
    # @param [String] fn the filename to which to write the correction
    # 
    # @return [void]
    #
    def write_to_file(fn)
      
      File.open(fn) do |f|

        f.write(write_to_xml)

      end

    end

    ##
    # Writes the correction to a string in XML format
    # 
    # @return [String] the correction data encoded as XML
    #
    def write_to_xml
      
      doc = REXML::Document.new

      ce = doc.add_element XML_STRINGS[:correction_element]

      ce.attributes[XML_STRINGS[:n_points_attr]] = @distance_cutoffs.size

      ce.attributes[XML_STRINGS[:ref_channel_attr]] = @reference_channel

      ce.attributes[XML_STRINGS[:corr_channel_attr]] = @correction_channel
      
      @distance_cutoffs.each_index do |i|

        cp = ce.add_element XML_STRINGS[:correction_point_element]

        cp.attributes[XML_STRINGS[:x_pos_attr]]= @positions_for_correction[i][0]
        cp.attributes[XML_STRINGS[:y_pos_attr]]= @positions_for_correction[i][1]
        cp.attributes[XML_STRINGS[:z_pos_attr]]= @positions_for_correction[i][2]

        xp = cp.add_element XML_STRINGS[:x_param_element]

        xp.text = @correction_x,join(", ")

        yp = cp.add_element XML_STRINGS[:y_param_element]

        yp.text = @correction_y.join(", ")

        zp = cp.add_element XML_STRINGS[:z_param_element]
        
        zp.text = @correction_z.join(", ")
        
      end

      bd = ce.add_element XML_STRINGS[:binary_data_element]

      bd.attributes[XML_STRINGS[:encoding_attr]]= XML_STRINGS[:encoding_name]

      bin_data = Base64.encode(Marshal.dump(self))

      bd.text = bin_data

      doc_string = ""

      doc.write doc_string

      doc_string

    end

    ##
    # Reads a correction from a specified file containing an XML-encoded correction.
    #
    # @param [String] fn the filename from which to read the correction
    #
    # @return [Correction] the correction contained in the file.
    #
    def self.read_from_file(fn)

      return nil unless File.exist?(fn)
      
      xml_str = ""

      File.open(fn) do |f|

        xml_str = f.read

      end

      doc = REXML::Document.new xml_str

      bin_el = doc.elements[1, XML_STRINGS[:binary_data_element]]

      Marshal.load(Base64.decode(bd.text))

    end

    ##
    # Calculates the 2d distances from a specified 2d point to the centroid of each of the image objects
    # used for the correction.
    #
    # @param [Numeric] x the x coordinate of the point
    # @param [Numeric] y the y coordinate of the point
    #
    # @return [Vector] the distance from the specified point to each image object.
    #
    def calculate_normalized_dists_to_centroids(x,y)

      dists_to_centroids = @positions_for_correction.column[0].map { |x0| (x0-x)**2 }

      dists_to_centroids += @positions_for_correction.column[1].map { |y0| (y0-y)**2 }

      dists_to_centroids = dists_to_centroids.map { |e| Math.sqrt(e) }

      dists_to_centroids.map2(@distance_cutoffs) { |e1, e2| e1/e2 }

    end

    ##
    # Calculates the weight of each local quadratic fit for correcting a specified point.
    #
    # @param (see #calculate_normalized_dists_to_centroids)
    #
    # @return [Vector] the weights for each local fit used for correction
    #
    def calculate_weights(x, y) 

      dist_ratio = calculate_normalized_dists_to_centroids(x,y)

      dist_ratio_mask = Vector.zero(dist_ratio.size)

      dist_ratio_mask = dist_ratio_mask.map2(dist_ratio) { |e1, e2| e2 <= 1 ? 1 : 0 }

      weights = dist_ratio.map { |e| -3*e**2 + 1 + 2*e**3 }

      weights.map2(dist_ratio_mask) { |e1, e2| e1*e2 }

    end

    ##
    # Selects the local fits and their associated image objects that are to be used for correcting
    # a specified point (i.e. those fits with nonzero weight).
    #
    # @param (see #calculate_normalized_dists_to_centroids)
    #
    # @return [OpenStruct, #cx, #cy, #cz, #x_vec, #y_vec, #weights] an OpenStruct containing the
    #  selected fits for the x dimension, y dimension, and z dimension; the x and y positions 
    #  of the selected image objects used for correction; and the weights of the fits
    #
    def find_points_for_correction(x,y)
      
      weights = calculate_weights(x,y)

      count_weights = weights.count { |e| e > 0 }

      raise UnableToCorrectError, "Incomplete coverate in correction dataset at (x,y) = (#{x}, #{y})." if count_weights == 0

      cx = MMatrix.zero(count_weights, @correction_x.column_size)
      cy = MMatrix.zero(count_weights, @correction_y.column_size)
      cz = MMatrix.zero(count_weights, @correction_z.column_size)
      
      x_vec = MVector.zero(count_weights)
      y_vec = MVector.zero(count_weights)

      kept_weights = MVector.zero(count_weights)

      kept_counter = 0

      weights.each_with_index do |w, i|

        if w > 0 then

          cx[kept_counter].replace(@correction_x.row(i))
          cy[kept_counter].replace(@correction_y.row(i))
          cz[kept_counter].replace(@correction_z.row(i))
          
          x_vec[kept_counter] = x - positions_for_correction[i,0]
          y_vec[kept_counter] = y - positions_for_correction[i,1]

          kept_weights[kept_counter] = weights[i]

          kept_counter += 1

        end

      end

      OpenStruct.new(cx: cx, 
                     cy: cy, 
                     cz: cz, 
                     x_vec: x_vec, 
                     y_vec: y_vec,
                     weights: kept_weights)

    end

    ##
    # Calculates the correction for a specified position.
    #
    # @param (see #calculate_normalized_dists_to_centroids)
    #
    # @return [MVector] a mutable vector containing the correction in the x, y, and z dimensions
    #  for the specified position.
    # 
    def correct_position(x, y)
 
      points = find_points_for_correction(x,y)

      x_corr = 0
      y_corr = 0
      z_corr = 0

      all_correction_parameters = MMatrix.columns([MVector.unit(count_weights), 
                                                  points.x_vec, 
                                                  points.y_vec, 
                                                  points.x_vec.map { |e| e**2 }, 
                                                  points.y_vec.map { |e| e**2 }, 
                                                  points.x_vec.map2(y_vec) { |e1, e2| e1*e2 }])

      count_weights.times do |i|

        x_corr += all_correction_parameters.row(i).inner_product(points.cx.row(i))*points.weights[i]
        y_corr += all_correction_parameters.row(i).inner_product(points.cy.row(i))*points.weights[i]
        z_corr += all_correction_parameters.row(i).inner_product(points.cz_mat.row(i))*points.weights[i]

      end

      sum_weights = points.weights.reduce(0.0) { |a,e| a + e }

      x_corr /= sum_weights
      y_corr /= sum_weights
      z_corr /= sum_weights

      MVector[x_corr, y_corr, z_corr]

    end

  end

end


