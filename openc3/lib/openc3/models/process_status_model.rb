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

require 'openc3/models/model'

module OpenC3
  # Stores the status about an process.
  class ProcessStatusModel < Model
    PRIMARY_KEY = 'openc3_process_status'

    attr_accessor :state
    attr_accessor :process_type
    attr_accessor :detail
    attr_accessor :output

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope:)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def self.all(scope:)
      all = super("#{scope}__#{PRIMARY_KEY}")
      # Sort by the time and reverse to put newest (latest timestamp) on top
      all.sort_by { |key, value| value['updated_at'] }.reverse
    end
    # END NOTE

    def initialize(
      name:,
      state: nil,
      process_type: nil,
      detail: nil,
      output: nil,
      updated_at: nil,
      plugin: nil,
      scope:
    )
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      @state = state
      @process_type = process_type
      @detail = detail
      @output = output
    end

    def as_json(*a)
      {
        'name' => @name,
        'state' => @state,
        'process_type' => @process_type,
        'detail' => @detail,
        'output' => @output,
        'plugin' => @plugin,
        'updated_at' => @updated_at
      }
    end
  end
end
