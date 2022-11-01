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

require 'thread'
require 'openc3/config/config_parser'
require 'openc3/topics/topic'
require 'openc3/utilities/bucket_utilities'

module OpenC3
  # Creates a log. Can automatically cycle the log based on an elasped
  # time period or when the log file reaches a predefined size.
  class LogWriter
    # @return [String] The filename of the packet log
    attr_reader :filename

    # @return [true/false] Whether logging is enabled
    attr_reader :logging_enabled

    # @return cycle_time [Integer] The amount of time in seconds before creating
    #   a new log file. This can be combined with cycle_size but is better used
    #   independently.
    attr_reader :cycle_time

    # @return cycle_hour [Integer] The time at which to cycle the log. Combined with
    #   cycle_minute to cycle the log daily at the specified time. If nil, the log
    #   will be cycled hourly at the specified cycle_minute.
    attr_reader :cycle_hour

    # @return cycle_minute [Integer] The time at which to cycle the log. See cycle_hour
    #   for more information.
    attr_reader :cycle_minute

    # @return [Time] Time that the current log file started
    attr_reader :start_time

    # @return [Mutex] Instance mutex protecting file
    attr_reader :mutex

    # Redis offsets for each topic to cleanup
    attr_accessor :cleanup_offsets

    # Time at which to cleanup
    attr_accessor :cleanup_time

    # The cycle time interval. Cycle times are only checked at this level of
    # granularity.
    CYCLE_TIME_INTERVAL = 10

    # Delay in seconds before trimming Redis streams
    CLEANUP_DELAY = 60

    # Time delta tolerance between packets - Will start a new file if greater
    TIME_TOLERANCE_NS = 1_000_000_000
    TIME_TOLERANCE_SECS = 1.0

    # Mutex protecting class variables
    @@mutex = Mutex.new

    # Array of instances used to keep track of cycling logs
    @@instances = []

    # Thread used to cycle logs across all log writers
    @@cycle_thread = nil

    # Sleeper used to delay cycle thread
    @@cycle_sleeper = nil

    # @param remote_log_directory [String] The path to store the log files
    # @param logging_enabled [Boolean] Whether to start with logging enabled
    # @param cycle_time [Integer] The amount of time in seconds before creating
    #   a new log file. This can be combined with cycle_size but is better used
    #   independently.
    # @param cycle_size [Integer] The size in bytes before creating a new log
    #   file. This can be combined with cycle_time but is better used
    #   independently.
    # @param cycle_hour [Integer] The time at which to cycle the log. Combined with
    #   cycle_minute to cycle the log daily at the specified time. If nil, the log
    #   will be cycled hourly at the specified cycle_minute.
    # @param cycle_minute [Integer] The time at which to cycle the log. See cycle_hour
    #   for more information.
    def initialize(
      remote_log_directory,
      logging_enabled = true,
      cycle_time = nil,
      cycle_size = 1000000000,
      cycle_hour = nil,
      cycle_minute = nil
    )
      @remote_log_directory = remote_log_directory
      @logging_enabled = ConfigParser.handle_true_false(logging_enabled)
      @cycle_time = ConfigParser.handle_nil(cycle_time)
      if @cycle_time
        @cycle_time = Integer(@cycle_time)
        raise "cycle_time must be >= #{CYCLE_TIME_INTERVAL}" if @cycle_time < CYCLE_TIME_INTERVAL
      end
      @cycle_size = ConfigParser.handle_nil(cycle_size)
      @cycle_size = Integer(@cycle_size) if @cycle_size
      @cycle_hour = ConfigParser.handle_nil(cycle_hour)
      @cycle_hour = Integer(@cycle_hour) if @cycle_hour
      @cycle_minute = ConfigParser.handle_nil(cycle_minute)
      @cycle_minute = Integer(@cycle_minute) if @cycle_minute
      @mutex = Mutex.new
      @file = nil
      @file_size = 0
      @filename = nil
      @start_time = Time.now.utc
      @first_time = nil
      @last_time = nil
      @cancel_threads = false
      @last_offsets = {}
      @cleanup_offsets = {}
      @cleanup_time = nil
      @previous_time_nsec_since_epoch = nil

      # This is an optimization to avoid creating a new entry object
      # each time we create an entry which we do a LOT!
      @entry = String.new

      # Always make sure there is a cycle thread - (because it does trimming)
      @@mutex.synchronize do
        @@instances << self

        unless @@cycle_thread
          @@cycle_thread = OpenC3.safe_thread("Log cycle") do
            cycle_thread_body()
          end
        end
      end
    end

    # Starts a new log file by closing the existing log file. New log files are
    # not created until packets are written by {#write} so this does not
    # immediately create a log file on the filesystem.
    def start
      @mutex.synchronize { close_file(false); @logging_enabled = true }
    end

    # Stops all logging and closes the current log file.
    def stop
      @mutex.synchronize { @logging_enabled = false; close_file(false) }
    end

    # Stop all logging, close the current log file, and kill the logging threads.
    def shutdown
      stop()
      @@mutex.synchronize do
        @@instances.delete(self)
        if @@instances.length <= 0
          @@cycle_sleeper.cancel if @@cycle_sleeper
          OpenC3.kill_thread(self, @@cycle_thread) if @@cycle_thread
          @@cycle_thread = nil
        end
      end
    end

    def graceful_kill
      @cancel_threads = true
    end

    # implementation details

    def create_unique_filename(ext = extension)
      # Create a filename that doesn't exist
      attempt = nil
      while true
        filename_parts = [attempt]
        filename_parts.unshift @label if @label
        filename = File.join(Dir.tmpdir, File.build_timestamped_filename([@label, attempt], ext))
        if File.exist?(filename)
          attempt ||= 0
          attempt += 1
        else
          return filename
        end
      end
    end

    def cycle_thread_body
      @@cycle_sleeper = Sleeper.new
      while true
        start_time = Time.now
        @@mutex.synchronize do
          @@instances.each do |instance|
            # The check against start_time needs to be mutex protected to prevent a packet coming in between the check
            # and closing the file
            instance.mutex.synchronize do
              utc_now = Time.now.utc
              # Logger.debug("start:#{@start_time.to_f} now:#{utc_now.to_f} cycle:#{@cycle_time} new:#{(utc_now - @start_time) > @cycle_time}")
              if instance.logging_enabled and
                (
                  # Cycle based on total time logging
                  (instance.cycle_time and (utc_now - instance.start_time) > instance.cycle_time) or

                  # Cycle daily at a specific time
                  (instance.cycle_hour and instance.cycle_minute and utc_now.hour == instance.cycle_hour and utc_now.min == instance.cycle_minute and instance.start_time.yday != utc_now.yday) or

                  # Cycle hourly at a specific time
                  (instance.cycle_minute and not instance.cycle_hour and utc_now.min == instance.cycle_minute and instance.start_time.hour != utc_now.hour)
                )
                instance.close_file(false)
              end

              # Check for cleanup time
              if instance.cleanup_time and instance.cleanup_time <= utc_now
                # Now that the file is in S3, trim the Redis stream up until the previous file.
                # This keeps one minute of data in Redis
                instance.cleanup_offsets.each do |redis_topic, cleanup_offset|
                  Topic.trim_topic(redis_topic, cleanup_offset)
                end
                instance.cleanup_offsets.clear
                instance.cleanup_time = nil
              end
            end
          end
        end

        # Only check whether to cycle at a set interval
        run_time = Time.now - start_time
        sleep_time = CYCLE_TIME_INTERVAL - run_time
        sleep_time = 0 if sleep_time < 0
        break if @@cycle_sleeper.sleep(sleep_time)
      end
    end

    # Starting a new log file is a critical operation so the entire method is
    # wrapped with a rescue and handled with handle_critical_exception
    # Assumes mutex has already been taken
    def start_new_file
      close_file(false)

      # Start log file
      @filename = create_unique_filename()
      @file = File.new(@filename, 'wb')
      @file_size = 0

      @start_time = Time.now.utc
      @first_time = nil
      @last_time = nil
      @previous_time_nsec_since_epoch = nil
      Logger.debug "Log File Opened : #{@filename}"
    rescue => err
      Logger.error "Error starting new log file: #{err.formatted}"
      @logging_enabled = false
      OpenC3.handle_critical_exception(err)
    end

    def prepare_write(time_nsec_since_epoch, data_length, redis_topic, redis_offset)
      # This check includes logging_enabled again because it might have changed since we acquired the mutex
      # Ensures new files based on size, and ensures always increasing time order in files
      if @logging_enabled and ((!@file or (@cycle_size and (@file_size + data_length) > @cycle_size)) or (@previous_time_nsec_since_epoch and @previous_time_nsec_since_epoch > (time_nsec_since_epoch + TIME_TOLERANCE_NS)))
        start_new_file()
      end
      @last_offsets[redis_topic] = redis_offset if redis_topic and redis_offset # This is needed for the redis offset marker entry at the end of the log file
      @previous_time_nsec_since_epoch = time_nsec_since_epoch
    end

    # Closing a log file isn't critical so we just log an error. NOTE: This also trims the Redis stream
    # to keep a full file's worth of data in the stream. This is what prevents continuous stream growth.
    def close_file(take_mutex = true)
      @mutex.lock if take_mutex
      begin
        if @file
          begin
            @file.close unless @file.closed?
            Logger.debug "Log File Closed : #{@filename}"
            date = first_timestamp[0..7] # YYYYMMDD
            bucket_key = File.join(@remote_log_directory, date, bucket_filename())
            BucketUtilities.move_log_file_to_bucket(@filename, bucket_key)
            # Now that the file is in storage, trim the Redis stream up until the previous file.
            # This keeps one file worth of data in Redis as a safety buffer
            unless @cleanup_time
              @last_offsets.each do |redis_topic, last_offset|
                @cleanup_offsets[redis_topic] = last_offset
                @cleanup_time = Time.now + CLEANUP_DELAY # Cleanup in 1 minute (or sooner if already set)
              end
              # Don't clear @last_offsets so they can be used when closing the file
            end
          rescue Exception => err
            Logger.instance.error "Error closing #{@filename} : #{err.formatted}"
          end

          @file = nil
          @file_size = 0
          @filename = nil
        end
      ensure
        @mutex.unlock if take_mutex
      end
    end

    def bucket_filename
      "#{first_timestamp}__#{last_timestamp}" + extension
    end

    def extension
      '.log'.freeze
    end

    def first_time
      Time.from_nsec_from_epoch(@first_time)
    end

    def last_time
      Time.from_nsec_from_epoch(@last_time)
    end

    def first_timestamp
      first_time().to_timestamp # "YYYYMMDDHHmmSSNNNNNNNNN"
    end

    def last_timestamp
      last_time().to_timestamp # "YYYYMMDDHHmmSSNNNNNNNNN"
    end
  end
end
