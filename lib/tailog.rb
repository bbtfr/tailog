require 'tailog/version'
require 'tailog/ext/file'
require 'sinatra/base'
require 'active_support/configurable'

module Tailog
  include ActiveSupport::Configurable

  config_accessor :log_path do
    File.expand_path("log", Dir.pwd)
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
      if params[:seek]
        erb :ajax
      else
        erb :index
      end
    end
  end
end
