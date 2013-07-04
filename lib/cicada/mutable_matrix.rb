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

require 'matrix'

##
# Extension to the standard library Matrix class making them mutable.
#
#class MMatrix < Matrix #disabled until the bug fix for the issue in the standard library that prevents useful subclasses is released

class MMatrix < Matrix
end

class Matrix 
  ##
  # Replaces a row in this matrix by copying the entries from another vector.
  # 
  # @param [Integer] i the index of the row to replace
  # @param [Vector, Array] other the vector or array whose contents will be copied
  #  to the specified row.
  #
  def replace_row(i, other)
    column_size.times do |j|
      self[i, j]= other[j]
    end
  end

  ##
  # Replaces a column in this matrix by copying the entries from another vector.
  # 
  # @param [Integer] j the index of the column to replace
  # @param [Vector, Array] other the vector or array whose contents will be copied
  #  to the specified column.
  #
  def replace_column(j, other)
    row_size.times do |i|
      self[i, j]= other[i]
    end
  end
  
  public :[]=
end

##
# Extension to the standard library Vector class making them mutable and adding 
# some additional functionality.
#
class MVector < Vector

  ##
  # Generates a zero vector of specified size.
  #
  # @param [Integer] size the size of the zero vector
  #
  # @return [MVector] a mutable vector of specified size containing all 0.0
  #
  def MVector.zero(size)
    elements(Array.new(size, 0.0), false)
  end

  ##
  # Generates a unit vector of specified size.
  #
  # @param [Integer] size the size of the unit vector
  # 
  # @return [MVector] a mutable vector of specified size containing all 1.0
  #
  def MVector.unit(size)
    MVector.elements(Array.new(size, 1.0), false)
  end

  ##
  # Replaces the contents of this vector with the contents of another vector.  This will not
  # change the size of the current vector and will replace entries only up to the current size.
  #
  # @param [Vector<Numeric>, Array<Numeric>] other a vector (or array, or other indexable 
  #  collection) with at least as many elements as this vector; its entries will replace
  #  this vector's entries
  #
  # @return [void]
  #
  def replace(other)
    self.each_with_index do |e,i|
      self[i] = other[i]
    end
  end

  public :[]=
end
