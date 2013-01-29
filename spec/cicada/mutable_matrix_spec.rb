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

describe MMatrix do

  before :each do

    @mat = MMatrix[[1,2], [3,4]]

  end

  it "should allow setting of individual entries" do

    @mat[0,1] = 5

    @mat[0,1].should == 5
    @mat[0,0].should == 1
    @mat[1,1].should == 4

  end

  it "should allow replacement of rows" do

    @mat.replace_row(0, [5,6])

    @mat[0,0].should == 5
    @mat[0,1].should == 6
    @mat[1,0].should == 3

  end

  it "should allow replacement of columns" do

    @mat.replace_column(0, [5,6])

    @mat[0,0].should == 5
    @mat[1,0].should == 6
    @mat[0,1].should == 2

  end

end

describe MVector do

  before :each do

    @vec = MVector.zero(3)

  end

  it "should allow setting of individual entries" do

    @vec[0] = 1

    @vec[0].should == 1

    @vec[1].should == 0

  end

end


