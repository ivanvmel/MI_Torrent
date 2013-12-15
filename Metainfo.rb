require './bencode.rb'
require 'digest/sha1'
require './MI_File.rb'
require 'timeout'
require 'monitor'

class Metainfo

  attr_accessor :trackers, :info_hash, :piece_length, :pieces, :num_pieces,
  :name, :multi_file, :top_level_directory, :file_array, :peers, :good_peers,
  :peer_threads, :bitfield, :piece_length, :block_request_size, :torrent_length, :current_piece

  @trackers
  @info_hash
  @piece_length
  @pieces
  @peers
  @num_pieces
  @multi_file
  @top_level_directory
  @file_array
  @peer_id
  @good_peers
  @timeout_val
  @bitfield
  @block_request_size
  @torrent_length
  def initialize(file_location)

    # FOR DEBUGGING, TEMPORARY
    @current_piece = 0

    @DEBUG = 0
    # five second timeout
    @timeout_val = 5

    #################################################
    # IMPORTANT, CURRENTLY NOT ADDING UDP TRACKERS ##
    #################################################

    # get the trackers

    @trackers = Array.new

    dict = BEncode::load(File.new(file_location))

    @piece_length = dict["info"]["piece length"]
    @num_pieces = (dict["info"]["pieces"].length / 20)
    @piece_hashes = Array.new
    @peer_id = "MI000167890123456789"
    #@peer_id =  "-AZ2060-123495832949"
    @good_peers = Array.new

    @top_level_directory = dict["info"]["name"]
    @file_array = Array.new
    @bitfield = String.new
    @lock = Monitor.new
    @block_request_size = 16384 # this is in bytes 2^14
    #@block_request_size = 32768

    if(dict["info"].include?("files")) then
      @multi_file = true
      # Deal with all of the files
      dict["info"]["files"].each{|mi_file|
        curr_file = MI_File.new(mi_file["path"], mi_file["length"])
        @file_array.push(curr_file)
      }

    else
      @multi_file = false
      curr_file =  MI_File.new(dict["info"]["name"], dict["info"]["length"])
      @file_array.push(curr_file)

    end

    # go through all of the pieces, in sets of 20
    dict["info"]["pieces"].each_char.each_slice(20){|slice|

      temp_hash_string = String.new

      slice.each{|a_byte| temp_hash_string.concat(a_byte.to_s()) }

      @piece_hashes.push(temp_hash_string)

    }

    if @DEBUG == 1 then

      puts "Piece Length #{@piece_length}"
      puts (dict["info"]["pieces"].length / 20)

    end

    @torrent_length = 0
    # get the total torrent length
    @file_array.each{|file| @torrent_length = @torrent_length + file.length}

    if dict["announce"] != nil and not dict["announce"].include?("udp") then
      @trackers.push(dict["announce"])
    end

    if dict["announce-list"] != nil then
      dict["announce-list"].each{|t| if not (t[0].include?("udp")) then @trackers.push(t[0]) end}
    end

    # make sure that we do not have two copies of announce
    @trackers.uniq!

    # compute the info hash here

    @info_hash =  Digest::SHA1.digest(dict["info"].bencode)
    #puts "HASH : " + Digest::SHA1.hexdigest(dict["info"].bencode)

    if(@trackers.size == 0) then
      puts "Zero trackers. Cannot proceed. Exiting."
      exit
    end

    # initialize bitfield to empty
    @bitfield = Bitfield.new(@num_pieces, self, false)

    if(@DEBUG == 1) then
      puts "The total number of pieces is : #{@num_pieces}"
      puts "The piece length is           : #{@piece_length}"
      puts "The block request size is     : #{@block_request_size}"
      puts "The total torrent length is   : #{@torrent_length}"
    end

    get_peers()

  end

  def add_to_good_peers(peer)
    @lock.synchronize do
      @good_peers.push(peer)
    end
  end

  def increment_piece()
    @lock.synchronize do
      @current_piece = @current_piece + 1
    end
  end

  def delete_from_good_peer(peer)
    @lock.synchronize do
      if(@good_peers.include?(peer))
        @good_peers.delete(peer)
      end
    end
  end

  def set_bitfield(piece, byte)
    @lock.synchronize do

      @bitfield.set_piece_and_block(piece, byte)

      if(@bitfield.check_if_full(piece)) then
        @bitfield.set_bit(piece, true)
      end

    end
  end

  def get_peers()

    tracker_list = @trackers
    peers = Array.new

    # for each tracker, get the peer list

    tracker_list.each{|tracker|

      # parameter hash table
      params = Hash.new

      # fill out the parameter hash
      params["info_hash"] = @info_hash
      params["numwant"] = 200
      params["peer_id"] = @peer_id
      params["compact"] = 1
      params["left"] = 1
      params["uploaded"] = 0
      params["downloaded"] = 0
      params["port"] = 6881
      params["event"] = "started"

      begin

        # create the tracker address
        uri = URI.parse(tracker)
        uri.query = URI.encode_www_form(params)

        res = ""
        # get request
        Timeout::timeout(@timeout_val){
          res = Net::HTTP.get_response(uri)
        }

        if res == "" then raise "Res is empty" end

        # read response
        res_dict = BEncode::load(res.body)

        # get the addresses
        addresses = res_dict["peers"]

        #  puts tracker

        addresses.each_byte.each_slice(6){|slice|

          port = slice[4] * 256
          port += slice[5]

          if port != 0 then

            byte_ip = Array.new
            byte_ip.push(slice[0])
            byte_ip.push(slice[1])
            byte_ip.push(slice[2])
            byte_ip.push(slice[3])

            string_ip = slice[0].to_s() + "." + slice[1].to_s() + "." + slice[2].to_s() + "." + slice[3].to_s()

            # Initialize our peer
            curr_peer = Peer.new(self, string_ip, port, byte_ip, @peer_id)

            peers.push(curr_peer)
          end

        }

      rescue
        # nothing to be done here
        # puts "Encountered an error with tracker : " + tracker
        #puts $!, $@
      end

    }

    if(peers.size() == 0) then
      puts "We have no peers to talk to. Cannot proceed. Exiting."
      exit
    end

    @peers = peers

  end

  def spawn_peer_threads()

    begin
      interval = 15

      #while true do

      puts "RESTARTING"

      @peer_threads = Array.new

      @peers.each{|peer|

        curr_thread = Thread.new(){
          run_algorithm(peer)
        }

        # wait for each thread to finish
        @peer_threads.push(curr_thread)
      }

      sleep(interval)

      #@peer_threads.each{|peer| peer.exit}

      #end

    rescue
      puts $!, $@
    end

  end

  def run_algorithm(peer)

    sleep_between = 0.2

    # handshake
    peer.handshake()

    sleep(sleep_between)

    if peer.connected == true then

      # keep track of the good peers

      add_to_good_peers(peer)

      peer.send_msg(peer.create_interested())

      #sleep(sleep_between)

      for i in (0 ... 1000) do

        sleep(sleep_between)

        #puts "Good peers : #{@good_peers.length}"

        a_message = peer.create_message()

        if(peer.peer_choking == false) then
          peer.send_msg(a_message)
        end

        sleep(sleep_between)
        peer.recv_msg()
        #sleep(sleep_between)

      end

      peer.socket.close
      # wait for the listener thread to finish
      #listener_thread.join

    else
      return
    end

  end

  # class ends here
end

