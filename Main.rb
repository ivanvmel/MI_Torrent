require './bencode.rb'
require './Metainfo.rb'
require './Peer.rb'
require 'net/http'
require 'uri'
require 'digest/sha1'
require 'fileutils'
require './Bitfield'

# this is the most recent file

meta_info_files = Array.new

# we take a comma separated list of trackers
torrents = ["ubuntu_recent.torrent"]

# for each tracker, get an associated meta-info file
torrents.each{|torrent|
  meta_info_files.push(Metainfo.new(torrent))
}

meta_info_files.each{|meta_info_file|

  meta_info_file.spawn_peer_threads()
}


# wait for the meta_info_peers to finish
meta_info_files.each{|meta_info_file|
  meta_info_file.peer_threads.each{|peer|
    peer.join
  }
  puts "The tracker gave me #{meta_info_file.peers.length} peers"
  puts "I have #{meta_info_file.good_peers.length} good peers"
}

