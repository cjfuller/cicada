# /* ***** BEGIN LICENSE BLOCK *****
#  * 
#  * Copyright (c) 2013 Colin J. Fuller
#  * 
#  * Permission is hereby granted, free of charge, to any person obtaining a copy
#  * of this software and associated documentation files (the "Software"), to deal
#  * in the Software without restriction, including without limitation the rights
#  * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  * copies of the Software, and to permit persons to whom the Software is
#  * furnished to do so, subject to the following conditions:
#  * 
#  * The above copyright notice and this permission notice shall be included in
#  * all copies or substantial portions of the Software.
#  * 
#  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  * SOFTWARE.
#  * 
#  * ***** END LICENSE BLOCK ***** */

require 'cicada/fitting/p3d_fitter'


describe Cicada::P3DFitter do

  before :each do 
    @fitter = Cicada::P3DFitter.new({})
  end

  it "should calculate p3d probability densities correctly" do

    r = 10.0
    m = 5.0
    s = 10.0

    expected = 0.04451

    allowed_error = 0.00001

    fct = Cicada::P3DObjectiveFunction.new

    (fct.p3d(r, m, s) - expected).abs.should be < allowed_error
    

  end

  it "should fit a p3d distribution correctly" do

    data = nil

    File.open("spec/resources/test_p3d_data.txt") do |f|
      data = f.readlines
    end

    data.map! { |e| e.to_f }

    result = @fitter.fit(nil, data)

    expected_m = 30.0
    expected_s = 10.0

    allowed_error = 1.0
    
    m = result[0]
    s = result[1]

    (m - expected_m).abs.should be < allowed_error
    (s - expected_s).abs.should be < allowed_error

  end
  

end


