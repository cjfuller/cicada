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

require 'spec_helper'

require 'cicada/correction/position_corrector'
require 'cicada/cicada_main'

require 'rimageanalysistools/create_parameters'

require 'ostruct'

describe Cicada::PositionCorrector do 
  
  before :each do 

    @p = {reference_channel: 0, channel_to_correct: 1, half_box_size: 3, half_z_size: 5, pixelsize_nm: 80, z_sectionsize_nm: 100, num_points: 36, num_wavelengths: 3, log_detailed_messages: true, max_threads: 10, photons_per_greylevel: 0.125, determine_correction: true, fit_error_cutoff: 10, correct_images: true}

  end


  def load_correction

    Cicada::Correction.read_from_file(CORR_FN)

  end


  def load_iobjs

    Cicada::FileInteraction.unserialize_position_data_file(OBJ_FN)

  end


  it "should generate a correction correctly" do

    pc = Cicada::PositionCorrector.new(@p)

    iobjs = load_iobjs

    c = pc.generate_correction(iobjs)
   
    xml_string = c.write_to_xml

    c_ref = load_correction

    ref_string = c_ref.write_to_xml

    xml_string.should == ref_string

  end


  it "should be able to correct image objects" do

    iobjs = load_iobjs

    iobjs_orig = iobjs

    iobjs = iobjs.select { |e| e.getLabel % 10 == 0 }

    pc = Cicada::PositionCorrector.new(@p)

    c = load_correction

    diffs = pc.apply_correction(c, iobjs)
    
    expected = [0.9648537061749035,
                0.5709395379024668,
                0.8858793228753269,
                1.0188179855284514,
                0.9905469052645519,
                1.5904787247607233,
                0.7160781864125757,
                0.6880017962144355,
                0.6415597673221431] #this is based on matching values to the java implementation

    expected.each_index do |i|

      expected[i].should == diffs[i]

    end
   
  end


  it "should correctly calculate the target registration error (TRE)" do

    pc = Cicada::PositionCorrector.new(@p)

    tre = pc.determine_tre(load_iobjs)

    expected_tre = 1.407 #value from java implementation

    allowed_error = 0.001

    (tre - expected_tre).abs.should be < allowed_error

  end


end

