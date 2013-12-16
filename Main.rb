require './bencode.rb'
require './Metainfo.rb'
require './Peer.rb'
require 'net/http'
require 'uri'
require 'digest/sha1'
require 'fileutils'
require './Bitfield'
require 'fileutils'


am_seeder = false

if (ARGV[0] == "seed") then
  am_seeder = true
elsif (ARGV[0] == "download") then
   # nothing, already not seeder
else
   puts "Invalid argument.  Appropriate arguments are 'download <filename>', or 'seed <filename>'. Exiting."
    exit
end

# Do something if file doesn't exist or whatever

if am_seeder then
  puts "I am a SEEDER"
else
  puts "I am a LEECHER"
end

meta_info_files = Array.new

seed_thread = nil

# data.each{|block|

filenames = Array.new
i = 1
while ARGV[i] != nil
  filenames.push(ARGV[i])
  i += 1
end


meta_info_files = Array.new
filenames = ["pizza.torrent"]
# we take a comma separated list of trackers
torrents = filenames

# for each tracker, get an associated meta-info file.
torrents.each{|torrent|
  meta_info_files.push(Metainfo.new(torrent))
}

meta_info_files.each{|meta_info_file|

  # THIS IS WHERE WE START SEEDING - the reason this works is because this only one meta-info file
  seed_thread = meta_info_file.seed()

  # THIS LITTLE BIT OF TIME IS FOR THE SERVER FIRING UP
  sleep(1)

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

seed_thread.join

=begin

  @bitfield
  @byte_length
  @meta_info_file
  @piece_field
  def initialize(length, meta_info_file, is_peer)

=end

# Loads file from current directory into piece map (shadow map).  Returns bitfield
def load_file(filename)
  # initialize seeder bitfield
  seeder_bf = Bitfield.new(length, nil, false)

end
