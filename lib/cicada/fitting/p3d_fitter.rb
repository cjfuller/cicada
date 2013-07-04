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

require 'rimageanalysistools'
require 'facets/math/mean'
require 'facets/math/std'

module Cicada

  ##
  # Interface for a class that fits a set of scalars with associated image object
  # to some distribution.
  #
  class DistributionFitter
    attr_accessor :parameters

    ##
    # Constructs a new distribution fitter from specified parameters.  Derived
    # classes should indicate which parameters are used.
    #
    # @param [ParameterDictionary, Hash] params a hash-like object containing the parameters
    #
    def initialize(params)
      @parameters = params
    end

    ##
    # Fits the data with associated image objects to the distribution.
    #
    # *Abstract*
    #
    # @param [Array<ImageObject>] objects the associated image objects
    # @param [Array<Numeric>] diffs the scalar data being fit (in the same order
    #  as the image objects)
    #
    # @return [Array<Numeric>] the fitted distribution parameters
    #
    def fit(objects, diffs)
      nil
    end
  end

  ##
  # An objective function that calculates the negative log likelihood of supplied data points
  # being generated from a p3d distribution with specified parameters.
  #
  # The data points should be an array of (positive) scalars set using the attribute r.
  #
  #
  class P3DObjectiveFunction
    include Java::edu.stanford.cfuller.imageanalysistools.fitting.ObjectiveFunction

    ##
    # Constructs an empty P3DObjectiveFunction.
    #
    def initialize
      @r = nil
      @s = nil
      @min_prob = nil
      @use_min_prob = false
      @should_fit_s = true
    end

    attr_accessor :r, :use_min_prob, :should_fit_s
    attr_reader :s, :min_prob
    
    ##
    # Sets a static value for the parameter that is the standard deviation of the generating
    # Gaussian distribution.  Setting this parameter disables its fitting by the objective function.
    #
    # @param [Numeric] s_new the static value for the standard deviation parameter
    #
    # @return [void]
    #
    def s=(s_new)
      @s = s_new
      @should_fit_s = false
    end

    ##
    # Sets a minimum probability cutoff for calculating the likelihood.  Could be used for various
    # robust fitting approaches.
    #
    # @param [Numeric] min_prob the minimum allowed probability for any data point.  Probabilities
    #  smaller than this value will be set to this value.
    # 
    # @return [void]
    #
    def min_prob=(min_prob)
      @min_prob = min_prob
      @use_min_prob = true
    end

    ##
    # Calculates the probability density of the p3d distribution at a given point.
    #
    # @param [Numeric] r the distance at which to calculate the probability density
    # @param [Numeric] m the mean-like parameter of the p3d distribution
    # @param [Numeric] s the standard-deviation-like parameter of the p3d distribution
    #
    # @return [Float] the probability density at the given point
    #
    def p3d(r, m, s)
      (Math.sqrt(2.0/Math::PI)*r/(2*m*s))*(Math.exp(-1 * (m-r)**2/(2*s**2)) - Math.exp( -1 * (m+r)**2/(2*s**2)))
    end

    ##
    # Evaluates the negative log-likelihood of the data given the parameters specified.
    #
    # @param [Array<Numeric>] point a 2-element array containing the mean- and standard deviation-like
    #  parameters.  If a static standard deviation parameter is being used, something should still be
    #  provided here, but it will be ignored.
    #
    # @return [Float] the negative log-likelihood of the data.
    #
    def evaluate(point)
      point = point.toArray unless point.is_a? Array
      m = point[0]
      s = point[1]
      s = @s unless @should_fit_s
      return Float::MAX if (m < 0 or s < 0)

      r.reduce(0.0) do |sum, ri|
        temp_neg_log_p = -1.0*Math.log( p3d(ri, m, s))
        if (@use_min_prob and temp_neg_log_p > @min_prob) then    
          sum + @min_prob
        else
          sum + temp_neg_log_p
        end
      end       
    end
  end

  ##
  # A distribution fitter that fits data to a P3D distribution.
  #
  class P3DFitter < DistributionFitter
    # parameters required by the methods in this class
    REQUIRED_PARAMETERS =  []

    # parmeters used but not required in this class or only required for optional functionality
    OPTIONAL_PARAMETERS = [:robust_p3d_fit_cutoff]

    ##
    # Fits the P3D mean- and standard-deviation-like parameters to the data.
    #
    # @param [Array<ImageObject>] objects the image objects whose distances are being fit
    # @param [Array<Numeric>] diffs the distances being fit
    #
    # @return [Array] a two-element array containing the mean- and standard-deviation-like parameters.
    #
    def fit(objects, diffs)
      of = P3DObjectiveFunction.new
      of.r = diffs
      tol = 1e-12
      nmm = Java::edu.stanford.cfuller.imageanalysistools.fitting.NelderMeadMinimizer.new(tol)
      initial_mean = Math.mean(diffs)
      initial_width = Math.std(diffs)
      starting_point = Java::org.apache.commons.math3.linear.ArrayRealVector.new(2, 0.0)
      starting_point.setEntry(0, initial_mean)
      starting_point.setEntry(1, initial_width)
      if @parameters[:robust_p3d_fit_cutoff] then  
        of.min_prob= @parmaeters[:robust_p3d_fit_cutoff].to_f
      end

      nmm.optimize(of, starting_point).toArray.to_a
    end
  end
end



