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
    @p = {}
    setup_default_parameters(@p)
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

  it "should be able to calculate coefficients for the in situ correction" do

    @p[:correct_images] = false
    @p[:channel_to_correct] = 2
    @p[:in_situ_aberr_corr_channel] = 1

    pc = Cicada::PositionCorrector.new(@p)

    corr = pc.generate_in_situ_correction_from_iobjs(load_iobjs).corr_parameters.transpose

    x_corr = corr[0]
    y_corr = corr[1]
    z_corr = corr[2]

    #these values match the java implementation; input values for image generation (pre-noise) were 1.32 slope and 0.05625 x,y intercept and 0.1125 z intercept
    expected_x = [1.28, 0.057]
    expected_y = [1.15, 0.058]
    expected_z = [1.32, 0.119]

    allowed_err = [0.01, 0.001]

    (expected_x[0] - x_corr[0]).abs.should be < allowed_err[0]
    (expected_x[1] - x_corr[1]).abs.should be < allowed_err[1]
    (expected_y[0] - y_corr[0]).abs.should be < allowed_err[0]
    (expected_y[1] - y_corr[1]).abs.should be < allowed_err[1]
    (expected_z[0] - z_corr[0]).abs.should be < allowed_err[0]
    (expected_z[1] - z_corr[1]).abs.should be < allowed_err[1]

  end

  
  it "should be able to apply the in situ correction" do 
    
    @p[:correct_images] = false
    @p[:channel_to_correct] = 2
    @p[:in_situ_aberr_corr_channel] = 1

    pc = Cicada::PositionCorrector.new(@p)

    corr = pc.generate_in_situ_correction_from_iobjs(load_iobjs)

    corrected = pc.apply_in_situ_correction(load_iobjs, corr)

    corrected.map! { |c| pc.apply_scale(c) }

    averages = [0, 0, 0]

    averages = corrected.reduce(averages) { |a, e| a.ewise + e.to_a }

    averages.map! { |e| e/corrected.length }

    Vector[*averages].norm.should be < 0.5

  end
    
  


end

