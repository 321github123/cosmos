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

require 'openc3/config/meta_config_parser'

class ScriptAutocompleteController < ApplicationController
  CMD_KEYWORDS = %w(cmd cmd_no_range_check cmd_no_hazardous_check cmd_no_checks
                    cmd_raw cmd_raw_no_range_check cmd_raw_no_hazardous_check cmd_raw_no_checks)

  TLM_KEYWORDS = %w(set_tlm override_tlm normalize_tlm tlm
                    limits_enabled? enable_limits disable_limits
                    check check_tolerance wait wait_tolerance wait_check wait_check_tolerance)

  def get_reserved_item_names
    render :json => OpenC3::Packet::RESERVED_ITEM_NAMES, :status => 200
  end

  def get_keywords
    keywords = case params[:type].upcase
    when 'CMD'
      CMD_KEYWORDS
    when 'TLM'
      TLM_KEYWORDS
    when 'SCREEN'
      get_screen_keywords()
    end
    render :json => keywords, :status => 200
  end

  def get_ace_autocomplete_data
    return unless authorization('system')
    autocomplete_data = build_autocomplete_data(params[:type], params[:scope])
    response.headers['Cache-Control'] = 'must-revalidate' # TODO: Browser is ignoring this and not caching anything for some reason. Future enhancement
    render :json => autocomplete_data, :status => 200
  end

  # private

  def get_screen_keywords
    keywords = []
    yaml = OpenC3::MetaConfigParser.load(File.join(OpenC3::PATH, 'data', 'config', 'screen.yaml'))
    yaml.each do |keyword, data|
      if data['collection']
        keywords.concat(data['collection'].keys)
      else
        keywords << keyword
      end
    end
    keywords
  end

  def build_autocomplete_data(type, scope)
    if type.upcase == 'SCREEN'
      yaml = OpenC3::MetaConfigParser.load(File.join(OpenC3::PATH, 'data', 'config', 'screen.yaml'))
      yaml.map.each do |keyword, data|
        if data['collection']
          data['collection'].each do |keyword, data|
            screen_to_autocomplete_hash(keyword, data)
          end
        else
          screen_to_autocomplete_hash(keyword, data)
        end
      end
    else
      autocomplete_data = OpenC3::TargetModel.all(scope: scope).flat_map do |target_name, target_info|
        OpenC3::TargetModel.packets(target_name, type: type.upcase.intern, scope: scope).flat_map do |packet|
          packet_to_autocomplete_hashes(packet, target_info, type)
        end
      end
      autocomplete_data.sort_by { |packet| packet[:caption] }
    end
  end

  def screen_to_autocomplete_hash(keyword, data)
    params = []
    if data['parameters']
      params = data['parameters'].collect { |param| param['name'] }
    end
    # The snippet is what gets put in the file when you autocomplete
    # Thus we put the keyword with all the parameters surround by <>
    # e.g. SCREEN <Width> <Height> <Polling Period>
    snippet = keyword.dup
    params.each_with_index.map do |item, index|
      # map to Ace autocomplete data syntax to allow tabbing through items: "${position:defaultValue}"
      snippet << " ${#{index + 1}:<#{item}>}"
    end
    {
      :caption => keyword,
      :snippet => snippet,
      :meta => data['summary'],
    }
  end

  def target_packet_name(packet)
    "#{packet['target_name']} #{packet['packet_name']}"
  end

  def packet_to_autocomplete_hashes(packet, target_info, type)
    if type.upcase == 'TLM'
      return packet['items'].map do |item|
        {
          :caption => "#{target_packet_name(packet)} #{item['name']}",
          :snippet => "#{target_packet_name(packet)} #{item['name']}",
          :meta => 'telemetry',
        }
      end
    else
      # There's only one autocomplete option for each command packet
      return [
        {
          :caption => target_packet_name(packet),
          :snippet => build_cmd_snippet(packet, target_info),
          :meta => 'command',
        }
      ]
    end
  end

  def build_cmd_snippet(packet, target_info)
    caption = target_packet_name(packet)
    filtered_items = packet['items'].select do |item|
      !OpenC3::Packet::RESERVED_ITEM_NAMES.include?(item['name']) and !target_info['ignored_parameters'].include?(item['name'])
    end
    if filtered_items.any?
      params = filtered_items.each_with_index.map do |item, index|
        default = item['default'] || 0
        if item.key? 'states'
          default_state = item['states'].find { |_key, val| val['value'] == default }
          default = default_state[0] if default_state
        end
        # map to Ace autocomplete data syntax to allow tabbing through items: "staticText ${position:defaultValue}"
        "#{item['name']} ${#{index + 1}:#{default}}"
      end
      return "#{caption} with #{params.join(', ')}"
    end
    caption
  end
end
