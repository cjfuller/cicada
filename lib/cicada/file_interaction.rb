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

module Cicada

  class FileInteraction


    REQUIRED_PARAMETERS = [:dirname_set, :basename_set, :mask_relative_dirname, :mask_extra_extension, :data_directory, :correction_date, :output_positions_to_directory]

    OPTIONAL_PARAMETERS = [:in_situ_aberr_corr_basename_set]

    POS_XML_EXTENSION = "_position_data.xml"

    CORR_XML_EXTENSION = "_correction.xml"

    DIFFS_TXT_EXTENSION = "_diffs.txt"

    MULTI_NAME_SEP = ","

    def self.position_data_filename(p)
      dir = p[:data_directory]
      File.expand_path(p[:basename_set].split(MULTI_NAME_SEP)[0] + POS_XML_EXTENSION, dir)
    end

    def self.position_file_exists?(p)
      File.exist?(FileInteraction.position_data_filename(p))
    end

    def self.read_position_data(p)
      
      fn = FileInteraction.position_data_filename(p)

      data_str = nil

      File.open(fn) do |f|
        data_str = f.read
      end

      FileInteraction.unserialize_xml_position_data(data_str)

    end

    def unserialize_xml_position_data(data_str)
      #TODO
    end

    def self.list_files(p)

      dirnames = p[:dirname_set].split(MULTI_NAME_SEP)
      basenames = p[:basename_set].split(MULTI_NAME_SEP)

      image_sets = []

      dirnames.each do |d|

        mask_dirname = File.join(d, p[:mask_relative_dirname])

        Dir.foreach(d) do |f|

          #is there an #any method on Enumerable?
          if basenames.reduce(false) { |a,e| a or f.match(e) } then
            
            im = File.expand_path(f, d)
            msk = File.expand_path(f + p[:mask_extra_extension], mask_dirname)

            #check this constructor
            current = OpenStruct.new(image_fn: im, mask_fn: msk)
            
            image_sets << current

          end          

        end

      end
      
      image_sets

    end

    def self.write_position_data(image_objects, p)
      #TODO
    end

    def self.correction_filename(p)

      dir = p[:data_directory]
      fn = p[:correction_date]

      File.expand_path(fn + CORR_XML_EXTENSION, dir)

    end

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


