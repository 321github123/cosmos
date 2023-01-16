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

require 'openc3/utilities/local_mode'
require 'openc3/utilities/bucket'

class StorageController < ApplicationController
  def buckets
    buckets = []
    buckets << ENV['OPENC3_CONFIG_BUCKET']
    buckets << ENV['OPENC3_LOGS_BUCKET']
    buckets << ENV['OPENC3_TOOLS_BUCKET']
    render :json => buckets, :status => 200
  end

  def files
    bucket = OpenC3::Bucket.getClient()
    path = params[:path]
    path = '/' if path.nil? || path.empty?
    results = bucket.list_files(bucket: params[:bucket], path: path)
    render :json => results, :status => 200
  end

  def get_download_presigned_request
    return unless authorization('system')
    bucket = OpenC3::Bucket.getClient()
    bucket_name = ENV[params[:bucket]] # Get the actual bucket name
    bucket.check_object(bucket: bucket_name, key: params[:object_id])
    result = bucket.presigned_request(bucket: bucket_name,
                                      key: params[:object_id],
                                      method: :get_object,
                                      internal: params[:internal])
    render :json => result, :status => 201
  end

  def get_upload_presigned_request
    return unless authorization('system_set')
    bucket = OpenC3::Bucket.getClient()
    bucket_name = ENV[params[:bucket]] # Get the actual bucket name
    result = bucket.presigned_request(bucket: bucket_name,
                                      key: params[:object_id],
                                      method: :put_object,
                                      internal: params[:internal])
    OpenC3::Logger.info("S3 upload presigned request generated: #{bucket_name}/#{params[:object_id]}",
        scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
    render :json => result, :status => 201
  end

  def delete
    return unless authorization('system_set')
    bucket_name = ENV[params[:bucket]] # Get the actual bucket name
    # Only allow deleting from targets_modified in config bucket
    raise "Invalid bucket key #{params[:bucket]} with val #{bucket_name}" if params[:bucket] != 'OPENC3_CONFIG_BUCKET'
    key_split = params[:object_id].to_s.split('/')
    raise "Invalid key: #{params[:object_id]}" if key_split[1] != 'targets_modified'

    if ENV['OPENC3_LOCAL_MODE']
      OpenC3::LocalMode.delete_local(params[:object_id])
    end

    OpenC3::Bucket.getClient().delete_object(bucket: bucket_name, key: params[:object_id])
    OpenC3::Logger.info("Deleted: #{bucket_name}/#{params[:object_id]}",
        scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
    head :ok
  end
end
