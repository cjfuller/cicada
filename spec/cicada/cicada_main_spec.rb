#--
# Copyright (c) 2013 Colin J. Fuller
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the Software), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++

require 'logger'

require 'spec_helper'

require 'cicada/correction/position_corrector'
require 'cicada/correction/correction'
require 'cicada/correction/in_situ_correction'
require 'cicada/cicada_main'
require 'cicada/file_interaction'

describe Cicada do

  before :each do 
    @p = {}
    setup_default_parameters(@p)
  end

  it "should not give an error when trying not to perform any correction and the correction file does not exist on disk" do
    @p[:determine_correction] = false
    @p[:correct_images] = false
    cic = Cicada::CicadaMain.new(@p)

    cic.class.class_eval do
      define_method :do_and_save_fits do
        load_iobjs
      end
    end

    Cicada::FileInteraction.class_eval do
      def self.write_position_data(iobjs, params)
        nil
      end
    end

    expect { cic.go }.not_to raise_exception

  end
end


