require './bencode.rb'
require './Metainfo.rb'
require './Peer.rb'
require 'net/http'
require 'uri'
require 'digest/sha1'
require 'fileutils'
require './Bitfield'

@sleep = 3
torrent = "ubuntu_recent.torrent"
meta_info_file = Metainfo.new(torrent)

# perform handshakes
handshake_threads = Array.new()
meta_info_file.peers().each{|peer| handshake_threads.push(Thread.new(){peer.handshake()}) }
handshake_threads.each{|handshake_thread| handshake_thread.join}

sleep(@sleep)

# recv information
recv_threads = Array.new()
meta_info_file.peers().each{|peer|
  if peer.connected then
    recv_threads.push(Thread.new(){peer.recv_msg()})
  end
}
recv_threads.each{|recv_thread| recv_thread.join}

=begin
# send our bitmap
bitmap_sender_threads = Array.new()
meta_info_file.peers().each{|peer|
  if(peer.connected) then
    bitmap_sender_threads.push(Thread.new(){peer.send_my_bitfield()})
  end
}
bitmap_sender_threads.each{|thread| thread.join}
=end

sleep(@sleep)

# recv information
recv_threads = Array.new()
meta_info_file.peers().each{|peer|
  if peer.connected then
    recv_threads.push(Thread.new(){peer.recv_msg()})
  end
}
recv_threads.each{|recv_thread| recv_thread.join}

sleep(@sleep)

# send our request
send_threads = Array.new()
meta_info_file.peers().each{|peer|
  if peer.peer_choking == false then

    puts peer.create_message().inspect
    send_threads.push(Thread.new(){peer.send(peer.create_message())})

  else
    puts "I am being choked"
  end
}
send_threads.join{|thread| thread.join}

sleep(@sleep)

# recv information
recv_threads = Array.new()
meta_info_file.peers().each{|peer|
  if peer.connected then
    recv_threads.push(Thread.new(){peer.recv_msg()})
  end
}
recv_threads.each{|recv_thread| recv_thread.join}

