require 'tailog/version'
require 'tailog/eval'
require 'tailog/request_id'
require 'tailog/watch_methods'
require 'tailog/ext/file'
require 'tailog/ext/integer'
require 'tailog/ext/irb'

require 'sinatra/base'
require 'socket'
require 'open3'
require 'json'

module Tailog
  extend Tailog::WatchMethods

  class << self
    attr_accessor :log_path, :request_id

    def server_hostname
      @server_hostname ||= Socket.gethostname
    end

    def process_uuid
      @process_uuid ||= SecureRandom.uuid
    end
  end

  self.log_path = File.expand_path("log", Dir.pwd)

  class App < Sinatra::Base
    set :root, File.expand_path("../../app", __FILE__)
    set :public_folder do "#{root}/assets" end
    set :views do "#{root}/views" end

    helpers do
      def h(text)
        Rack::Utils.escape_html(text)
      end
    end

    get '/' do
      redirect to('/logs')
    end

    get '/logs' do
      erb :'logs/index'
    end

    post '/logs' do
      begin
        file_path = File.join Tailog.log_path, params[:file]
        file = File.open file_path
        file_size = file.size
        tail = if seek = params[:seek] && params[:seek][Tailog.server_hostname]
          file.seek seek.to_i
          file
        else
          file.tail(100).join("\n")
        end
        content = erb :'logs/list', locals: { file: tail }, layout: false
        file.close
      rescue => error
        content = erb :error, locals: { error: error }, layout: false
      end

      {
        server_hostname: Tailog.server_hostname,
        process_uuid: Tailog.process_uuid,
        file_size: file_size,
        content: content
      }.to_json
    end

    get '/env' do
      erb :env
    end

    get '/script' do
      erb :'script/index'
    end

    post '/script' do
      result = {
        server_hostname: Tailog.server_hostname,
        process_uuid: Tailog.process_uuid
      }

      ignore_content = false
      if params[:broadcast]
        instance_id = result[:instance_id] = params[:type] == "bash" ? Tailog.server_hostname : Tailog.process_uuid
        discovered_instances = params[:discovered_instances] || []
        ignore_content = true if discovered_instances.include? instance_id
      end

      result[:content] = erb :"script/#{params[:type]}", locals: { script: params[:script] }, layout: false unless ignore_content

      result.to_json
    end
  end
end
