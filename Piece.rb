class Piece

  attr_accessor :block_field, :leftovers, :num_blocks
  
  def initialize(block_size, piece_size)

    @block_field = Array.new
    @leftovers = piece_size % block_size
    @num_blocks = piece_size / block_size

    if leftovers != 0 then @num_blocks = @num_blocks + 1 end

    for i in (0 ... @num_blocks) do
      @block_field.push(false)
    end

  end

end