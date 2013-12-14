class Bitfield
  attr_accessor :bitfield, :byte_length

  @bitfield
  def initialize(length)

    @bitfield = Array.new
    for counter in 0...length
      @bitfield.push(false)
    end

    @byte_length = (@bitfield.length / 8.0).ceil

  end

  # This method converts the data structure to the sendable bitmap
  def struct_to_string()

    # This function indexes 0 at the left end of the byte

    bitfield_string = String.new

    @bitfield.each_slice(8){|slice|

      curr_byte = 0

      for i in (0 ... slice.length) do

        if(slice[i] == true) then
          # Magic !!!
          curr_byte += (2 ** (7 - i))
        end
      end

      bitfield_string.concat(curr_byte.chr)

    }

    return bitfield_string

  end

  # this method syncs the bitmap input with the underlying bit array
  def set_bitfield_with_bitmap(input)

    offset = 0
    input.each_char{|curr_char|

      mike = 0
      for i in (0 ... 8) do

        mike = curr_char.each_byte.first & (2 ** (7 - i))

        if(mike != 0) then
          @bitfield[offset + i] = true
        end

      end
      offset += 8

    }

  end

  def struct_to_ones_and_zeroes()
    output = String.new

    counter = 1

    for i in (0 ... @bitfield.length) do
      if(@bitfield[i] == true) then
        output.concat("1")
      else
        output.concat("0")
      end

      if(counter % 8 == 0) then
        output.concat(" ")
      end
      counter = counter + 1
    end

    return output
  end

  def set_bit(n, t_or_f)

    if(n < 0 || n >= @bitfield.length) then
      raise "Out of bounds bitfield operation"
    end

    if(t_or_f == true) then @bitfield[n] = true else @bitfield[n] = false end

  end

end
