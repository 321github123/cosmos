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

require 'openc3/models/router_model'
require 'openc3/models/router_status_model'
require 'openc3/topics/router_topic'

module OpenC3
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
                       'get_router',
                       'get_router_names',
                       'connect_router',
                       'disconnect_router',
                       'start_raw_logging_router',
                       'stop_raw_logging_router',
                       'get_all_router_info',
                     ])

    # Get information about a router
    #
    # @param router_name [String] Router name
    # @return [Hash] Hash of all the router information
    def get_router(router_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', router_name: router_name, scope: scope, token: token)
      router = RouterModel.get(name: router_name, scope: scope)
      raise "Router '#{router_name}' does not exist" unless router

      router.merge(RouterStatusModel.get(name: router_name, scope: scope))
    end

    # @return [Array<String>] All the router names
    def get_router_names(scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      RouterModel.names(scope: scope)
    end

    # Connects a router and starts its command gathering thread
    #
    # @param router_name [String] Name of router
    # @param router_params [Array] Optional parameters to pass to the router
    def connect_router(router_name, *router_params, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      RouterTopic.connect_router(router_name, *router_params, scope: scope)
    end

    # Disconnects a router and kills its command gathering thread
    #
    # @param router_name [String] Name of router
    def disconnect_router(router_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      RouterTopic.disconnect_router(router_name, scope: scope)
    end

    # Starts raw logging for a router
    #
    # @param router_name [String] The name of the interface
    def start_raw_logging_router(router_name = 'ALL', scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      if router_name == 'ALL'
        get_router_names().each do |router_name|
          RouterTopic.start_raw_logging(router_name, scope: scope)
        end
      else
        RouterTopic.start_raw_logging(router_name, scope: scope)
      end
    end

    # Stop raw logging for a router
    #
    # @param router_name [String] The name of the interface
    def stop_raw_logging_router(router_name = 'ALL', scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      if router_name == 'ALL'
        get_router_names().each do |router_name|
          RouterTopic.stop_raw_logging(router_name, scope: scope)
        end
      else
        RouterTopic.stop_raw_logging(router_name, scope: scope)
      end
    end

    # Consolidate all router info into a single API call
    #
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all routers
    def get_all_router_info(scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      RouterStatusModel.all(scope: scope).each do |router_name, router|
        info << [router['name'], router['state'], router['clients'], router['txsize'], router['rxsize'],\
                 router['txbytes'], router['rxbytes'], router['rxcnt'], router['txcnt']]
      end
      info.sort! { |a, b| a[0] <=> b[0] }
      info
    end
  end
end
