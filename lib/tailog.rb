require 'tailog/version'
require 'sinatra/base'
require 'active_support/configurable'
require 'tailog/ext/file'
require 'securerandom'
require 'json'

module Tailog
  include ActiveSupport::Configurable

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
        seek = params[:seek] && params[:seek][Tailog.server_uuid] || file_size
        file.seek seek.to_i
        content = erb :'logs/list', locals: { file: file }, layout: false
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
  end
end
