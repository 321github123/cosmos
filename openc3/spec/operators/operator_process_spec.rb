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

require 'spec_helper'
require 'openc3/operators/operator'

module OpenC3
  describe OperatorProcess do
    describe "start" do
      it "starts the process" do
        spy = spy('ChildProcess')
        expect(spy).to receive(:start)
        expect(ChildProcess).to receive(:build).with('ruby', 'filename.rb', 'DEFAULT__SERVICE__NAME').and_return(spy)

        capture_io do |stdout|
          op = OperatorProcess.new(
            ['ruby', 'filename.rb', 'DEFAULT__SERVICE__NAME'],
            scope: 'DEFAULT',
            config: { 'cmd' => ["ruby", "service_microservice.rb", 'DEFAULT__SERVICE__NAME'] }
          )
          op.start
          expect(stdout.string).to include('Starting: ruby service_microservice.rb DEFAULT__SERVICE__NAME')
        end
      end
    end
  end
end
