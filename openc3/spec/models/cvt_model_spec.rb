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
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
#
# This file may also be used under the terms of a commercial license
# if purchased from OpenC3, Inc.

require 'spec_helper'
require 'openc3/models/cvt_model'

module OpenC3
  describe CvtModel do
    def update_temp1
      json_hash = {}
      json_hash["TEMP1"]    = 1
      json_hash["TEMP1__C"] = 2
      json_hash["TEMP1__F"] = "2.00"
      json_hash["TEMP1__U"] = "2.00 C"
      CvtModel.set(json_hash, target_name: "INST", packet_name: "HEALTH_STATUS", scope: "DEFAULT")
    end

    def check_temp1
      expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")).to eql 1
      expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :CONVERTED, scope: "DEFAULT")).to eql 2
      expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :FORMATTED, scope: "DEFAULT")).to eql "2.00"
      expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :WITH_UNITS, scope: "DEFAULT")).to eql "2.00 C"
    end

    before(:each) do
      mock_redis()
      setup_system()
    end

    describe "self.set" do
      it "sets multiple values in the CVT" do
        update_temp1()
        check_temp1()
      end

      it "decoms and sets" do
        packet = Packet.new("TGT", "PKT", :BIG_ENDIAN, 'packet', "\x01\x02")
        packet.append_item("ary", 8, :UINT, 16)
        i = packet.get_item("ARY")
        i.read_conversion = GenericConversion.new("value * 2")
        i.format_string = "0x%x"
        i.units = 'V'

        json_hash = CvtModel.build_json_from_packet(packet)
        CvtModel.set(json_hash, target_name: packet.target_name, packet_name: packet.packet_name, scope: 'DEFAULT')

        expect(CvtModel.get_item("TGT", "PKT", "ARY", type: :RAW, scope: "DEFAULT")).to eql [1, 2]
        expect(CvtModel.get_item("TGT", "PKT", "ARY", type: :CONVERTED, scope: "DEFAULT")).to eql [2, 4]
        expect(CvtModel.get_item("TGT", "PKT", "ARY", type: :FORMATTED, scope: "DEFAULT")).to eql '["0x2", "0x4"]'
        expect(CvtModel.get_item("TGT", "PKT", "ARY", type: :WITH_UNITS, scope: "DEFAULT")).to eql '["0x2 V", "0x4 V"]'
      end
    end

    describe "self.del" do
      it "deletes a target / packet from the CVT" do
        update_temp1()
        expect(Store.hkeys("DEFAULT__tlm__INST")).to eql ["HEALTH_STATUS"]
        CvtModel.del(target_name: "INST", packet_name: "HEALTH_STATUS", scope: "DEFAULT")
        expect(Store.hkeys("DEFAULT__tlm__INST")).to eql []
      end
    end

    describe "self.set_item" do
      it "raises for an unknown type" do
        expect { CvtModel.set_item("INST", "HEALTH_STATUS", "TEMP1", 0, type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type 'OTHER'/)
      end

      it "temporarily sets a single value in the CVT" do
        update_temp1()

        CvtModel.set_item("INST", "HEALTH_STATUS", "TEMP1", 0, type: :RAW, scope: "DEFAULT")
        # Verify the :RAW value changed
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")).to eql 0
        # Verify none of the other values change
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :CONVERTED, scope: "DEFAULT")).to eql 2
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :FORMATTED, scope: "DEFAULT")).to eql "2.00"
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :WITH_UNITS, scope: "DEFAULT")).to eql "2.00 C"

        CvtModel.set_item("INST", "HEALTH_STATUS", "TEMP1", 0, type: :CONVERTED, scope: "DEFAULT")
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :CONVERTED, scope: "DEFAULT")).to eql 0
        # Even thought we set 0 (Integer) we should get back a string "0"
        CvtModel.set_item("INST", "HEALTH_STATUS", "TEMP1", 0, type: :FORMATTED, scope: "DEFAULT")
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :FORMATTED, scope: "DEFAULT")).to eql "0"
        # Even thought we set 0 (Integer) we should get back a string "0"
        CvtModel.set_item("INST", "HEALTH_STATUS", "TEMP1", 0, type: :WITH_UNITS, scope: "DEFAULT")
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :WITH_UNITS, scope: "DEFAULT")).to eql "0"

        # Simulate TEMP1 being updated by a new packet
        update_temp1()
        # Verify we're all back to normal
        check_temp1()
      end
    end

    describe "self.get_item" do
      it "raises for an unknown type" do
        expect { CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type 'OTHER'/)
      end

      it "falls down to the next type value if the requested type doesn't exist" do
        json_hash = {}
        # TEMP2 is RAW, CONVERTED, FORMATTED only
        json_hash["TEMP2"]    = 3 # Values must be JSON encoded
        json_hash["TEMP2__C"] = 4
        json_hash["TEMP2__F"] = "4.00"
        # TEMP3 is RAW, CONVERTED only
        json_hash["TEMP3"]    = 5 # Values must be JSON encoded
        json_hash["TEMP3__C"] = 6
        # TEMP3 is RAW only
        json_hash["TEMP4"]    = 7 # Values must be JSON encoded
        CvtModel.set(json_hash, target_name: "INST", packet_name: "HEALTH_STATUS", scope: "DEFAULT")

        # Verify TEMP2
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP2", type: :RAW, scope: "DEFAULT")).to eql 3
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP2", type: :CONVERTED, scope: "DEFAULT")).to eql 4
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP2", type: :FORMATTED, scope: "DEFAULT")).to eql "4.00"
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP2", type: :WITH_UNITS, scope: "DEFAULT")).to eql "4.00" # Same as FORMATTED
        # Verify TEMP3
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP3", type: :RAW, scope: "DEFAULT")).to eql 5
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP3", type: :CONVERTED, scope: "DEFAULT")).to eql 6
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP3", type: :FORMATTED, scope: "DEFAULT")).to eql "6" # Same as CONVERTED but String
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP3", type: :WITH_UNITS, scope: "DEFAULT")).to eql "6" # Same as CONVERTED but String
        # Verify TEMP4
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP4", type: :RAW, scope: "DEFAULT")).to eql 7
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP4", type: :CONVERTED, scope: "DEFAULT")).to eql 7 # Same as RAW
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP4", type: :FORMATTED, scope: "DEFAULT")).to eql "7" # Same as RAW but String
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP4", type: :WITH_UNITS, scope: "DEFAULT")).to eql "7" # Same as RAW but String
      end
    end

    describe "override" do
      it "raises for an unknown type" do
        expect { CvtModel.override("INST", "HEALTH_STATUS", "TEMP1", 0, type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type 'OTHER'/)
      end

      it "overrides a value in the CVT" do
        update_temp1()
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")).to eql 1
        CvtModel.override("INST", "HEALTH_STATUS", "TEMP1", 0, type: :RAW, scope: "DEFAULT")
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")).to eql 0
        # Simulate TEMP1 being updated by a new packet
        update_temp1()
        # Verify we're still over-ridden
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")).to eql 0
      end
    end

    describe "normalize" do
      it "raises for an unknown type" do
        expect { CvtModel.normalize("INST", "HEALTH_STATUS", "TEMP1", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type 'OTHER'/)
      end

      it "normalizes an override value type in the CVT" do
        update_temp1()
        CvtModel.override("INST", "HEALTH_STATUS", "TEMP1", 0, type: :RAW, scope: "DEFAULT")
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")).to eql 0
        CvtModel.normalize("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")
        check_temp1()
      end

      it "normalizes every value type in the CVT" do
        update_temp1()
        CvtModel.override("INST", "HEALTH_STATUS", "TEMP1", 10, type: :RAW, scope: "DEFAULT")
        CvtModel.override("INST", "HEALTH_STATUS", "TEMP1", 10, type: :CONVERTED, scope: "DEFAULT")
        CvtModel.override("INST", "HEALTH_STATUS", "TEMP1", 10, type: :FORMATTED, scope: "DEFAULT")
        CvtModel.override("INST", "HEALTH_STATUS", "TEMP1", 10, type: :WITH_UNITS, scope: "DEFAULT")
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :RAW, scope: "DEFAULT")).to eql 10
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :CONVERTED, scope: "DEFAULT")).to eql 10
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :FORMATTED, scope: "DEFAULT")).to eql 10
        expect(CvtModel.get_item("INST", "HEALTH_STATUS", "TEMP1", type: :WITH_UNITS, scope: "DEFAULT")).to eql 10
        CvtModel.normalize("INST", "HEALTH_STATUS", "TEMP1", type: :ALL, scope: "DEFAULT")
        check_temp1()
      end
    end
  end
end
