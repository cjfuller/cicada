# /* ***** BEGIN LICENSE BLOCK *****
#  * 
#  * Copyright (c) 2012 Colin J. Fuller
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

module Cicada

  class DistributionFitter

    attr_accessor :parameters

    def initialize(params)

      @parameters = params

    end

    def fit(objects, diffs)
      nil
    end
    

  end

  class P3DObjectiveFunction

    include Java::edu.stanford.cfuller.imageanalysistools.fitting.ObjectiveFunction

    def initialize

      @r = nil
      @s = nil
      @min_prob = nil
      @use_min_prob = false
      @should_fit_s = true

    end

    attr_accessor :r, :use_min_prob, :should_fit_s

    attr_reader :s, :min_prob

    def s=(s_new)
      @s = s_new
      @should_fit_s = false
    end

    def min_prob=(min_prob)

      @min_prob = min_prob
      @use_min_prob = true

    end

    def p3d(r, m, s)

      (Math.sqrt(2.0/Math::PI)*r/(2*m*s))*(Math.exp(-1 * (m-r)**2/(2*s**2)) - Math.exp( -1 * (m+r)**2/(2*s**2)))

    end

    def evaluate(point)
      
      m = point[0]
      s = point[1]
      s = @s unless @should_fit_s

      return Float::MAX if (m < 0 or s < 0)

      r.reduce(0.0) do |sum, ri|

        temp_neg_log_p = -1.0*Math.log( p3d(r, m, s))

        if (@use_min_prob and temp_neg_log_p > @min_prob) then
          
          sum + @min_prob

        else

          sum + temp_neg_log_p

        end

      end
        
    end

  end
  

  class P3DFitter < DistributionFitter

    REQUIRED_PARAMETERS =  [:marker_channel_index, :channel_to_correct]

    OPTIONAL_PARAMETERS = [:robust_p3d_fit_cutoff]

    def fit(objects, diffs)

      of = P3DObjectiveFunction.new

      of.r = diffs

      tol = 1e-12

      nmm = Java::edu.stanford.cfuller.imageanalysistools.fitting.NelderMeadMinimizer.new(tol)

      initial_mean = (diffs.reduce(0.0) { |a, e| a + e })/diffs.length

      initial_width = Math.sqrt((diffs.reduce(0.0) { |a, e| a + (e - initial_mean)**2 })/diffs.length)

      starting_point = Java::org.apache.commons.math3.ArrayRealVector.new(2, 0.0)

      starting_point.setEntry(0, initialMean)
      starting_point.setEntry(1, initialWidth)

      if @parameters[:robust_p3d_fit_cutoff] then
        
        of.min_prob= @parmaeters[:robust_p3d_fit_cutoff].to_f

      end

      nmm.optimize(of, starting_point)

    end
    



  end

end



