# encoding: ascii-8bit

# Copyright 2022 OpenC3, Inc.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This file may also be used under the terms of a commercial license
# if purchased from OpenC3, Inc.

require 'openc3/logs/packet_log_reader'
require 'openc3/logs/packet_log_writer'

module OpenC3
  # Buffers files so small time differences can be read in time order
  class BufferedPacketLogReader < PacketLogReader

    attr_reader :bucket_file

    def initialize(bucket_file = nil, buffer_depth = 10)
      super()
      @bucket_file = bucket_file
      @buffer_depth = buffer_depth
    end

    def next_packet_time(identify_and_define = true)
      fill_buffer(identify_and_define)
      packet = @buffer[0]
      return packet.packet_time if packet
      return nil
    end

    def buffered_read(identify_and_define = true)
      fill_buffer(identify_and_define)
      return @buffer.shift
    end

    protected

    def fill_buffer(identify_and_define = true)
      while true
        break if @buffer.length >= @buffer_depth
        packet = read(identify_and_define)
        break unless packet
        packet = packet.dup if identify_and_define
        @buffer << packet
        @buffer.sort! {|pkt1, pkt2| pkt1.packet_time <=> pkt2.packet_time }
      end
    end

    def reset
      super()
      @buffer = []
    end

  end
end
