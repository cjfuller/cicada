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

require 'cicada/file_interaction'

describe Cicada::Serialization do 

  it "should be able to serialize and unserialize a set of image objects" do

    iobjs = load_iobjs

    to_ser = iobjs[0,3]

    ser_str = Cicada::Serialization.serialize_image_objects(to_ser)

    objs_out = Cicada::Serialization.unserialize_image_objects(ser_str)

    objs_out[0].getPositionForChannel(0).getEntry(0).should == to_ser[0].getPositionForChannel(0).getEntry(0)

    objs_out[1].getPositionForChannel(0).getEntry(0).should == to_ser[1].getPositionForChannel(0).getEntry(0)

    objs_out[2].getPositionForChannel(0).getEntry(0).should == to_ser[2].getPositionForChannel(0).getEntry(0)

    objs_out[0].nil?.should be false

    objs_out[1].nil?.should be false

    objs_out[2].nil?.should be false

  end

end



