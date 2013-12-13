class Message

  attr_accessor :id, :length, :payload
  # keep-alive messages have an id of -1, length of length of 4 and payload of nil
  def initialize(id, length, payload)

    # This field is parsed
    @id = id

    # This field is parsed
    @length = length

    # This field is not parsed (literally the bytes we were sent)
    @payload = payload
  end
end
