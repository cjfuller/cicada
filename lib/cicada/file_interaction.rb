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

require 'ostruct'
require 'base64'
require 'rexml/document'
require 'csv'

require 'rimageanalysistools'
require 'rimageanalysistools/get_image'

module Cicada

  ##
  # Handles the serialization of the ImageObjects for storing them in a file.
  #
  # The serialized output will consist of an XML file describing the objects
  # in human-readable form and including a binary data sectiobn containing the
  # serialized object.  This binary section is the only thing read back in, so
  # changing the XML human-readable portion of the file manually will not affect
  # the data read back in.
  #
  class Serialization
    
    ##
    # Converts an array of ImageObjects to an XML-formatted string containing
    # the serialized data.
    #
    # @param [Enumerable<ImageObject>] image_objects an Enumerable list of image objects
    #
    # @return [String] a string containing formatted XML and binary representations of the 
    #  image objects.
    #
    def self.serialize_image_objects(image_objects)
      doc = REXML::Document.new
      doc.add_element "root"

      image_objects.each do |iobj|
        in_doc = REXML::Document.new iobj.writeToXMLString
        in_doc.root.elements[1, "serialized_form"].text = Base64.encode64(Marshal.dump(iobj))
        doc.root.add in_doc.elements[1,"image_object"]
      end

      output = ""
      doc.write(output, 2)
      output
    end

    ##
    # Restores an image object from a byte string.
    #
    # @param [String] bin_data the bytes representing the image object.  This should be 
    #  a standard byte string.  The XML files use base64 encoding, and the data should already
    #  be unencoded.
    #
    # @return [ImageObject] the encoded ImageObject
    #
    def self.image_object_from_bytes(bin_data)
      Marshal.load(bin_data)
    end

    ##
    # Restores image objects from an XML string containing their serialized representation.
    # (This uses the base64 encoded binary information in the XML file, not the human readable portion.)
    #
    # @param [String] data the XML string
    #
    # @return [Array<ImageObject>] the image objects encoded in the string
    #
    def self.unserialize_image_objects(data)
      objs = []
      doc = REXML::Document.new data

      doc.elements.each("*/image_object/serialized_form") do |el|
        bin_data = Base64.decode64(el.text)
        objs << image_object_from_bytes(bin_data)
      end

      objs
    end
  end


  ##
  # A collection of methods for interacting with input and output files for cicada.
  # 
  class FileInteraction
    # parameters required by the methods in this class
    REQUIRED_PARAMETERS = [:dirname_set, :basename_set, :mask_relative_dirname, :mask_extra_extension, :data_directory, :correction_date, :output_positions_to_directory]

    # parmeters used but not required in this class or only required for optional functionality
    OPTIONAL_PARAMETERS = [:in_situ_aberr_corr_basename_set]

    # extension on position data (image object) files.
    POS_XML_EXTENSION = "_position_data.xml"

    # extension on human-friendly position data (image object) files.
    POS_HUMAN_EXTENSION = "_position_data.csv"

    # extension on the correction files
    CORR_XML_EXTENSION = "_correction.xml"

    # extension on the distance measurement files
    DIFFS_TXT_EXTENSION = "_diffs.txt"

    # separator used in the parameter file for multiple files, directories, etc.
    MULTI_NAME_SEP = ","

    ##
    # Loads an image from the specified file.
    #
    # @param [String] image_fn the image's filename
    #
    # @return [ReadOnlyImage] the image at the specified filename
    #
    def self.load_image(image_fn)
      RImageAnalysisTools.get_image(image_fn)
    end

    ##
    # Gets the filename to which / from which image object positions will be written / 
    # read from a parameter dictionary.
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the filename for the positions.
    #
    # @return [String] the absolute path to the position file.
    #
    def self.position_data_filename(p)
      dir = p[:data_directory]
      File.expand_path(p[:basename_set].split(MULTI_NAME_SEP)[0] + POS_XML_EXTENSION, dir)
    end

    ##
    # Gets the filename to which human-friendly-formatted object positions will be written.
    #
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the filename for the positions.
    #
    # @return [String] the absolute path to the position file.
    #
    def self.human_friendly_position_data_filename(p)
      dir = p[:data_directory]
      File.expand_path(p[:basename_set].split(MULTI_NAME_SEP)[0] + POS_HUMAN_EXTENSION, dir)
    end

    ##
    # Gets the filename of data to use for in situ correction from a parameter dictionary.
    #
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the filename for the
    #  in situ correction data
    #
    # @return [String] the absolute path to the in situ correction data file
    #
    def self.in_situ_corr_data_filename(p)
      dir = [:data_directory]
      File.expand_path(p[:in_situ_aberr_corr_basename_set].split(MULTI_NAME_SEP)[0] + POS_XML_EXTENSION, dir)
    end

    ##
    # Checks if the position data file already exists.
    # 
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the filename for the positions.
    #
    # @return [Boolean] whether the position data file exists.
    #
    def self.position_file_exists?(p)
      File.exist?(FileInteraction.position_data_filename(p))
    end

    ##
    # Unserializes image object position data from a specified file using the methods in the Serialization
    #  class.
    #
    # @param [String] fn the name of the data file.
    #
    # @return [Array<ImageObject>] the image objects contained in the file.
    #
    def self.unserialize_position_data_file(fn)
      data_str = nil
      File.open(fn) do |f|
        data_str = f.read
      end
      Serialization.unserialize_image_objects(data_str)
    end

    ##
    # Reads the image objects associated with an analysis specified by a parameter dictionary.
    #
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the filename for the positions.
    #
    # @return [Array<ImageObject>] the image objects associated with the analysis
    #
    def self.read_position_data(p)
      fn = FileInteraction.position_data_filename(p)
      FileInteraction.unserialize_position_data_file(fn)
    end

    ##
    # Reads the image objects for in situ correction associated with an analysis specified by
    #  a parameter dictionary.
    #
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the filename for the
    #  in situ correction data
    #
    # @return [Array<ImageObject>] the image objects for in situ correction associated with the analysis
    #
    def self.read_in_situ_corr_data(p)
      fn = FileInteraction.in_situ_corr_data_filename(p)
      FileInteraction.unserialize_position_data_file(fn)
    end

    ##
    # Lists all the files and masks to be analyzed given a parameter dictionary.
    #
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the analysis
    #
    # @return [Array<OpenStruct>] an array of objects that respond to #image_fn and #mask_fn, 
    #  which return each image's filename and its paired mask's filename respectively.
    #
    def self.list_files(p)
      dirnames = p[:dirname_set].split(MULTI_NAME_SEP)
      basenames = p[:basename_set].split(MULTI_NAME_SEP)
      image_sets = []

      dirnames.each do |d|
        mask_dirname = File.join(d, p[:mask_relative_dirname])
        Dir.foreach(d) do |f|
          if basenames.any? { |e| f.match(e) } then    
            im = File.expand_path(f, d)
            msk = File.expand_path(f + p[:mask_extra_extension], mask_dirname)
            current = OpenStruct.new(image_fn: im, mask_fn: msk)    
            image_sets << current
          end          
        end
      end    
      image_sets
    end

    ##
    # Writes the provided image objects to file to the location specified in a parameter dictionary.
    #
    # @param [Enumerable<ImageObject>] image_objects the objects that will be written to file. 
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the filename for the data.
    # 
    # @return [void]
    #
    def self.write_position_data(image_objects, p)
      fn = position_data_filename(p)
      write_position_data_file(image_objects,fn)
      fn2 = human_friendly_position_data_filename(p)
      write_human_friendly_position_data_file(image_objects, fn2)
    end

    ##
    # Writes the provided image objects to file to the location specified.
    #
    # @param [Enumerable<ImageObject>] image_objects the objects that will be written to file. 
    # @param [String] fn the filename of the file to which to write the data
    # 
    # @return [void]
    #
    def self.write_position_data_file(image_objects, fn)
      File.open(fn, 'w') do |f|
        f.write(Serialization.serialize_image_objects(image_objects))
      end
    end

    ##
    # Writes the provided image objects to a human-readable file 
    # at the location specified.
    #
    # @see write_position_data_file
    #
    def self.write_human_friendly_position_data_file(image_objects, fn)
      CSV.open(fn, 'wb') do |csv|
        obj = image_objects[0]
        n_channels = obj.getFitParametersByChannel.size
        headers = ["object_id"]
        n_channels.times do |i|
          headers.concat(["pos#{i}_x", "pos#{i}_y", "pos#{i}_z"])
        end
        csv << headers

        image_objects.each do |im_obj|
          row = [im_obj.getLabel]
          n_channels.times do |i|
            row.concat(im_obj.getPositionForChannel(i).toArray)
          end
          csv << row
        end
      end
    end

    ##
    # Gets the filename for storing/reading the correction based upon the supplied parameter dictionary.
    #
    # @param [ParameterDictionary, Hash] p a hash-like object specifying the correction file location.
    #
    # @return [String] the filename for the correction file.
    #
    def self.correction_filename(p)
      dir = p[:data_directory]
      fn = p[:correction_date]
      File.expand_path(fn + CORR_XML_EXTENSION, dir)
    end

    ##
    # Writes an array of distance measurements to file based upon the supplied parameter dictionary.
    # 
    # @param [Enumerable<#to_s>] diffs an enumerable list of distance meaurements.
    # @param [ParameterDictionary, hash] p a hash-like object specifying the file location.
    #
    # @return [void]
    #
    def self.write_differences(diffs, p)
      dirname = p[:output_positions_to_directory]
      fn = File.expand_path(p[:basename_set] + DIFFS_TXT_EXTENSION, dirname)
      File.open(fn, 'w') do |f|
        diffs.each do |d|
          f.puts(d.to_s)
        end
      end
    end
  end
end
