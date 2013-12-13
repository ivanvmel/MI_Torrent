class Message

  attr_accessor :id, :length, :payload
  # keep-alive messages have an id of -1, length of length of 4 and payload of nil
  def initialize(id, length, payload)
    @id = id
    @length = length
    @payload = payload
  end
end