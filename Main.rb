require './bencode.rb'
require './Metainfo.rb'
require './Peer.rb'
require 'net/http'
require 'uri'
require 'digest/sha1'
require 'fileutils'
require './Bitfield'
require 'fileutils'

meta_info_files = Array.new

# we take a comma separated list of trackers
torrents = ["ubuntu_recent.torrent"]

# for each tracker, get an associated meta-info file.
torrents.each{|torrent|
  meta_info_files.push(Metainfo.new(torrent))
}


meta_info_files.each{|meta_info_file|

  # make top level directory, if necessary.
  if (meta_info_file.multi_file == true) then
    FileUtils.mkdir(meta_info_file.top_level_directory)
  end

  # Make the rest of the directory tree.
  if (meta_info_file.multi_file == true) then
    puts "Path has to be interpreted as dictionary for multi-file, cant open"
    puts "exiting..."
    exit
  else
    meta_info_file.file_array[0].fd = 
      File.open(meta_info_file.file_array[0].path, "w")
  end

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

# clean up
meta_info_files.each{ |meta_info_file|
    if (meta_info_file.multi_file == true) then
    puts "Path has to be interpreted as dictionary for multi-file, cant close"
    puts "exiting..."
    exit
  else
    meta_info_file.file_array[0].fd.close
  end
}


