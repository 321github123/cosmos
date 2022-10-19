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

require 'open-uri'
require 'nokogiri'
require 'httpclient'
require 'rubygems'
require 'rubygems/uninstaller'
require 'tempfile'
require 'openc3/utilities/bucket'
require 'openc3/utilities/process_manager'
require 'openc3/api/api'

module OpenC3
  # This class acts like a Model but doesn't inherit from Model because it doesn't
  # actual interact with the Store (Redis). Instead we implement names, get, put
  # and destroy to allow interaction with gem files from the PluginModel and
  # the GemsController.
  class GemModel
    extend Api

    @@bucket_initialized = false

    def self.names
      bucket = initialize_bucket()
      gems = []
      bucket.list_objects(bucket: 'gems').each do |object|
        gems << object.key
      end
      gems
    end

    def self.get(dir, name)
      bucket = initialize_bucket()
      path = File.join(dir, name)
      bucket.get_object(bucket: 'gems', key: name, path: path)
      return path
    end

    def self.put(gem_file_path, gem_install: true, scope:)
      bucket = initialize_bucket()
      if File.file?(gem_file_path)
        gem_filename = File.basename(gem_file_path)
        Logger.info "Installing gem: #{gem_filename}"
        File.open(gem_file_path, 'rb') do |file|
          bucket.put_object(bucket: 'gems', key: gem_filename, body: file)
        end
        if gem_install
          result = OpenC3::ProcessManager.instance.spawn(["ruby", "/openc3/bin/openc3cli", "geminstall", gem_filename], "gem_install", gem_filename, Time.now + 3600.0, scope: scope)
          return result
        end
      else
        message = "Gem file #{gem_file_path} does not exist!"
        Logger.error message
        raise message
      end
      return nil
    end

    def self.install(name_or_path, scope:)
      temp_dir = Dir.mktmpdir
      begin
        if File.exist?(name_or_path)
          gem_file_path = name_or_path
        else
          gem_file_path = get(temp_dir, name_or_path)
        end
        begin
          rubygems_url = get_setting('rubygems_url', scope: scope)
        rescue
          # If Redis isn't running try the ENV, then simply rubygems.org
          rubygems_url = ENV['RUBYGEMS_URL']
          rubygems_url ||= 'https://rubygems.org'
        end
        Gem.sources = [rubygems_url] if rubygems_url
        Gem.done_installing_hooks.clear
        Gem.install(gem_file_path, "> 0.pre", :build_args => ['--no-document'], :prerelease => true)
      rescue => err
        message = "Gem file #{gem_file_path} error installing to /gems\n#{err.formatted}"
        Logger.error message
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
      end
    end

    def self.destroy(name)
      bucket = initialize_bucket()
      Logger.info "Removing gem: #{name}"
      bucket.delete_object(bucket: 'gems', key: name)
      gem_name, version = self.extract_name_and_version(name)
      begin
        Gem::Uninstaller.new(gem_name, {:version => version, :force => true}).uninstall
      rescue => err
        message = "Gem file #{name} error uninstalling\n#{err.formatted}"
        Logger.error message
      end
    end

    def self.extract_name_and_version(name)
      split_name = name.split('-')
      gem_name = split_name[0..-2].join('-')
      version = split_name[-1]
      return gem_name, version
    end

    # private

    def self.initialize_bucket
      bucket = Bucket.getClient()
      unless @@bucket_initialized
        bucket.create('gems')
        @@bucket_initialized = true
      end
      return bucket
    end
  end
end
