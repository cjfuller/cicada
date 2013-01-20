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

require 'cicada/correction/correction'

require 'spec_helper'

describe Cicada::Correction do

  XY_SIZE_NM = 80.0
  Z_SIZE_NM = 100.0

  DISTANCE_CONVERSIONS = Vector[XY_SIZE_NM, XY_SIZE_NM, Z_SIZE_NM]
  
  def expected_aberr(x,y)

    x_aberr = (1024 - (x)*4 -1)*0.01/80.0/4
    y_aberr = (1024 - (y)*4 -1)*0.01/80.0/4
    z_aberr = (((x)*4+1)*0.04 + (1024 - (y)*4-1)*0.04)/100.0/2

    Vector[x_aberr, y_aberr, z_aberr]

  end

  def get_diff_from_expected(x_test, y_test, c)
    
    corr = c.correct_position(x_test, y_test)

    exp = expected_aberr(x_test, y_test)

    corr = corr.map2(DISTANCE_CONVERSIONS) { |e1, e2| e1*e2 }

    exp = exp.map2(DISTANCE_CONVERSIONS) { |e1, e2| e1*e2 }

    (corr - exp).norm

  end

  it "should calculate the right correction given a position" do

    c = Cicada::Correction.read_from_file(CORR_FN)

    x = [99.75, 20.0, 122.0, 37.98, 200.0, 223.44]
    y = [54.75, 90.0, 220.0, 77.43, 189.0, 120.30]

    expected_error = [1.671, 
                      1.103,
                      0.459,
                      1.286,
                      1.243,
                      2.385] #values based on java implementation


    allowed_error = 0.001

    diffs = []

    x.each_index do |i|

      diffs << get_diff_from_expected(x[i], y[i], c)

    end

    remaining_error = expected_error.ewise - diffs

    remaining_error.map! { |e| e.abs }

    remaining_error.each do |e|

      e.should be < allowed_error

    end
    
  end


  it "should be the same after writing to and reading from XML" do

    c = Cicada::Correction.read_from_file(CORR_FN)

    xml_string = c.write_to_xml
    
    ref_string = Cicada::Correction.read_from_xml(xml_string).write_to_xml
  
    xml_string.should == ref_string

  end


end

