require 'timeout'
require './Message.rb'

class Peer

  attr_accessor :string_ip, :byte_ip, :port, :info_hash, :connected, :bitfield
  def initialize(meta_info_file, string_ip, port, byte_ip, peer_id)

    # keep_alive has an id of -1, it is treated specially for our implementation - it's length is zero
    @keep_alive_id = -1

    # these do not have a payload
    @choke_id = 0
    @unchoke_id = 1
    @interested_id = 2
    @not_interested_id = 3

    # these have a payload
    @have_id = 4
    @bitfield_id = 5
    @request_id = 6
    @piece_id = 7
    @cancel_id = 8
    @port_id = 9

    @meta_info_file = meta_info_file
    @pstr = "BitTorrent protocol"
    @pstrlen = "\x13"
    @reserved = "\x00\x00\x00\x00\x00\x00\x00\x00"
    @string_ip = string_ip
    @port = port
    @byte_ip = byte_ip
    @peer_id = peer_id
    @info_hash = meta_info_file.info_hash
    @handshake_info = "\x13BitTorrent protocol\x00\x00\x00\x00\x00\x00\x00\x00#{info_hash}#{peer_id}"
    @bitfield = Bitfield.new(meta_info_file.num_pieces)

    @connected = false

    @peer_choking = true
    @peer_interested = false
    @am_choking = true
    @am_interested = true

    @timeout_val = 10

    # not set here
    @last_recv_time
    @last_sent_time

    @DEBUG = 0

    if @DEBUG == 1 then
      puts "--- PEER CONSTRUCTED ---"
      puts "pstr      : #{@pstr}"
      puts "pstrlen   : #{@pstrlen}"
      puts "reserved  : #{@reserved}"
      puts "info_hash : #{@info_hash}"
      puts "peer_id   : #{@peer_id}"
      puts "string_ip : #{@string_ip}"
      puts "byte_ip   : #{@byte_ip}"
      puts "port      : #{@port}"
      puts "handshake : #{@handshake_info}"
      puts "--- PEER CONSTRUCTED ---"
    end

  end

  def handshake()

    begin

      Timeout::timeout(@timeout_val){

        @socket = TCPSocket.new(@string_ip, @port)
        @socket.write @handshake_info

        handshake = @socket.read 68

        if(handshake[28..47] != @info_hash) then
          Thread.exit
        end

        @connected = true

      }

    rescue
      # puts "could not connect to : " + @string_ip
      # $stdout.flush
    end

    # documentation :
    # this method receives a message from the peer and parses the message
    # said message returns a message data structure, return nil if timeout

    def recv_msg()

      debug = false

      begin

        Timeout::timeout(@timeout_val){

          length = 0
          id = 0
          data = @socket.recv(4)

          # make sure we actually got something
          if data == nil then
            @meta_info_file.delete_from_good_peer(self)
            Thread.exit
          end

          # how many more bytes we are to recv
          length += data.each_byte.to_a[0] * (2 ** 24)
          length += data.each_byte.to_a[1] * (2 ** 16)
          length += data.each_byte.to_a[2] * (2 ** 8)
          length += data.each_byte.to_a[3]

          additional_data = @socket.recv(length)

          #puts "ADVRTIZD LENGTH : #{Thread.current.object_id} #{length}"
          #puts "ADDITION LENGTH : #{Thread.current.object_id} #{additional_data.each_byte.to_a.length}"

          $stdout.flush

          # if you are not sending as much data as you advertise, we drop you BOOM
          if(additional_data.each_byte.to_a.length != length) then
            @meta_info_file.delete_from_good_peer(self)
            Thread.exit
          end

          if(debug) then
            puts "length of data to be recvd : #{length}"
            puts "length of data recv'd      : #{additional_data.each_byte.to_a.length}"
          end

          if(length != 0) then
            message_id = additional_data.each_byte.to_a[0]
          else
            message_id = -1
          end

          new_message = Message.new(message_id, length, additional_data[1...additional_data.length])

          # update recv time
          @last_recv_time = Time.new

          case message_id

          when @keep_alive_id
            puts "I got a KEEP-ALIVE id, code doesn't do anything about this yet"

          when @choke_id
            @peer_choking = true
            puts "I got choke id"

          when @unchoke_id
            @peer_choking = false
            puts "I got unchoke_id"

          when @interested_id
            @peer_interested = true
            puts "I got interested_id"

          when @not_interested_id
            @peer_interested = false
            puts "I got not_interested_id"

          when @have_id

            # update bitfield

            # Parse out numberic bitIdx
            bitIdx = 0
            bitIdx += new_message.payload().each_byte.to_a[0] * (2 ** 24)
            bitIdx += new_message.payload().each_byte.to_a[1] * (2 ** 16)
            bitIdx += new_message.payload().each_byte.to_a[2] * (2 ** 8)
            bitIdx += new_message.payload().each_byte.to_a[3]

            # Update corresponding bitIdx in bitfield
            @bitfield.set_bit(bitIdx, true)

            puts "I got have_id: #{bitIdx}"

          when @bitfield_id
            puts new_message.payload().each_byte.to_a.length
            @bitfield.set_bitfield_with_bitmap(new_message.payload())
            puts "I got bitfield_id"

          when @request_id
            puts "I got request_id"

          when @piece_id
            puts "I got piece_id"

          when @cancel_id
            puts "I got cancel_id"

          when @port_id
            puts "I got port_id"

          else
            puts "You gave me #{message_id} -- I have no idea what to do with that."
            $stdout.flush
            @meta_info_file.delete_from_good_peer(self)
            Thread.exit
          end

          $stdout.flush

        }

      rescue Timeout::Error => e
        # puts $!, $@
        puts "Encountered a timeout error."
        @meta_info_file.delete_from_good_peer(self)
        Thread.exit

      rescue Errno::ECONNRESET => e
        puts "Connection Reset by peer."
        @meta_info_file.delete_from_good_peer(self)
        Thread.exit

      rescue # any other error
        #puts $!, $@
        puts "Encountered a non-timeout error."
        @meta_info_file.delete_from_good_peer(self)
        Thread.exit
      end

    end

  end

  def send_my_bitfield()

    # I NEED A TRY - CATCH

    # the + 1 is for the id
    bitfield_length = @meta_info_file.bitfield.byte_length + 1
    id = "\x05";

    # this is used for packing
    temp = Array.new
    temp.push(bitfield_length)

    # the > specifies the endian-ness
    encoded_length = temp.pack("L>")

    bitfield_message = "#{id}#{encoded_length}#{@meta_info_file.bitfield.struct_to_string}"

    @socket.write bitfield_message

  end

  def send_msg(message)

    puts message.get_processed_message()

    @socket.write message.get_processed_message()

  end

  def get_random_piece()

    common_pieces_indices = Array.new
    peer_bitfield = @bitfield.bitfield
    our_bitfield = @meta_info_file.bitfield.bitfield

    for i in (0 ... our_bitfield.length) do

      if(peer_bitfield[i] == true && our_bitfield[i] == false) then common_pieces_indices.push(i) end

    end

    # we now know the indices of the pieces which the peer has but we do not
    random_location = rand(0 ... common_pieces_indices.length)

    if(random_location == nil)
      return nil
    else
      return common_pieces_indices[random_location]
    end

  end

  def create_message()

    if(@peer_choking) then
      # if the peer is choking us, we want to express our interest in her
      return Message.new(@interested_id, 1, "")
    else
      # if the peer is not choking us, we want a piece of her
      random_piece = get_random_piece()

      if(random_piece != nil) then
        return (Message.new(6, 13, random_piece))
      else
        return nil
      end

    end

  end

  # Class ends here

end

