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

require 'rimageanalysistools/fitting/bisquare_linear_fit'

module Cicada
  class InSituCorrection
    attr_accessor :reference_channel, :in_situ_corr_second_channel, :correction_channel, :parameters, :corr_parameters

    def initialize(ref_ch, in_situ_ch, corr_ch, iobjs, disable_intercept)
      self.reference_channel = ref_ch
      self.in_situ_corr_second_channel = in_situ_ch
      self.correction_channel = corr_ch
      @disable_intercept = disable_intercept

      calculate_in_situ_corr(iobjs)
    end

    def disable_intercept?
      @disable_intercept
    end

    def calculate_in_situ_corr(iobjs)
      corr_diffs = Matrix.rows(iobjs.map { |iobj| iobj.getCorrectedVectorDifferenceBetweenChannels(reference_channel, in_situ_corr_second_channel).toArray })
      expt_diffs = Matrix.rows(iobjs.map { |iobj| iobj.getCorrectedVectorDifferenceBetweenChannels(reference_channel, correction_channel).toArray })

      bslf = BisquareLinearFit.new
      bslf.disableIntercept if disable_intercept?
      all_parameters = 0.upto(corr_diffs.column_size - 1).collect do |i|
        bslf.fit_rb(corr_diffs.column(i), expt_diffs.column(i)).toArray
      end
     
      self.corr_parameters = all_parameters.transpose
    end

    def apply(iobjs)
      corrected_differences = iobjs.map do |iobj|
        corr_diff = iobj.getCorrectedVectorDifferenceBetweenChannels(reference_channel, in_situ_corr_second_channel).toArray.to_a
        expt_diff = iobj.getCorrectedVectorDifferenceBetweenChannels(reference_channel, correction_channel).toArray.to_a
        correction = (corr_diff.ewise * corr_parameters[0]).ewise + corr_parameters[1]
        Vector.elements(expt_diff.ewise - correction, false)
      end

      corrected_differences  
    end
  end
end

