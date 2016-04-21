require 'tailog/version'
require 'tailog/watch_methods'
require 'tailog/ext/file'

require 'sinatra/base'
require 'active_support/configurable'

require 'securerandom'
require 'open3'
require 'json'

module Tailog
  include ActiveSupport::Configurable
  extend Tailog::WatchMethods

  config_accessor :log_path do
    File.expand_path("log", Dir.pwd)
  end

  config_accessor :server_uuid do
    SecureRandom.uuid
  end

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
        tail = if seek = params[:seek] && params[:seek][Tailog.server_uuid]
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
        server_uuid: Tailog.server_uuid,
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
      content = erb :"script/#{params[:type]}", locals: { script: params[:script] }, layout: false

      {
        content: content
      }.to_json
    end
  end
end
