# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2023, OpenC3, Inc.
# All Rights Reserved
#
# This file may also be used under the terms of a commercial license
# if purchased from OpenC3, Inc.

require 'spec_helper'
require 'openc3/logs/stream_log_pair'

module OpenC3
  describe StreamLogPair do
    describe "initialize" do
      it "requires a name" do
        expect { StreamLogPair.new }.to raise_error(ArgumentError)
      end

      it "sets the write log and read log" do
        pair = StreamLogPair.new('MYINT')
        expect(pair.read_log).not_to be_nil
        expect(pair.write_log).not_to be_nil
        expect(pair.read_log.logging_enabled).to be true
        expect(pair.write_log.logging_enabled).to be true
        expect(pair.read_log.cycle_time).to be 600
        expect(pair.write_log.cycle_time).to be 600
        expect(pair.read_log.cycle_size).to be 50_000_000
        expect(pair.write_log.cycle_size).to be 50_000_000
        pair.shutdown
        sleep 0.01

        pair = StreamLogPair.new('MYINT2', [300, 100_000])
        expect(pair.read_log).not_to be_nil
        expect(pair.write_log).not_to be_nil
        expect(pair.read_log.logging_enabled).to be true
        expect(pair.write_log.logging_enabled).to be true
        expect(pair.read_log.cycle_time).to be 300
        expect(pair.write_log.cycle_time).to be 300
        expect(pair.read_log.cycle_size).to be 100_000
        expect(pair.write_log.cycle_size).to be 100_000
        pair.shutdown
        sleep 0.01
      end
    end

    describe "stop & start" do
      it "stops and starts logging" do
        pair = StreamLogPair.new('MYINT')
        expect(pair.write_log.logging_enabled).to be true
        expect(pair.read_log.logging_enabled).to be true
        pair.stop
        expect(pair.write_log.logging_enabled).to be false
        expect(pair.read_log.logging_enabled).to be false
        pair.start
        expect(pair.write_log.logging_enabled).to be true
        expect(pair.read_log.logging_enabled).to be true
        pair.shutdown
        sleep 0.01
      end
    end

    describe "clone" do
      it "clones itself including logging state" do
        pair = StreamLogPair.new('MYINT')
        expect(pair.write_log.logging_enabled).to be true
        expect(pair.read_log.logging_enabled).to be true
        pair_clone1 = pair.clone
        pair.stop
        pair.shutdown
        sleep 0.01
        expect(pair.write_log.logging_enabled).to be false
        expect(pair.read_log.logging_enabled).to be false
        expect(pair_clone1.write_log.logging_enabled).to be true
        expect(pair_clone1.read_log.logging_enabled).to be true
        pair_clone2 = pair.clone
        expect(pair_clone1.write_log.logging_enabled).to be true
        expect(pair_clone1.read_log.logging_enabled).to be true
        expect(pair_clone2.write_log.logging_enabled).to be false
        expect(pair_clone2.read_log.logging_enabled).to be false
        pair_clone1.shutdown
        sleep 0.01
        pair_clone2.shutdown
        sleep 0.01
      end
    end
  end
end
