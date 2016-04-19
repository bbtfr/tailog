require 'tailog/version'
require 'sinatra/base'

class File

  def tail(n)
    buffer = 1024
    idx = size > buffer ? size - buffer : 0
    chunks = []
    lines = 0

    begin
      seek(idx)
      chunk = read(buffer)
      break unless chunk
      lines += chunk.count("\n")
      chunks.unshift chunk
      idx -= buffer
    end while lines < ( n + 1 ) && idx >= 0

    chunks.join('').split(/\n/).last(n)
  end
end

module Tailog

  class << self
    attr_accessor :log_path
    attr_accessor :basic_auth
  end

  self.log_path = File.expand_path("log", Dir.pwd)
  self.basic_auth = proc do |username, password|
    username == (ENV['TAILOG_USERNAME'] || 'tailog') and
      password == (ENV['TAILOG_USERNAME'] || 'password')
  end

  class App < Sinatra::Base
    set :root, File.expand_path("../../app", __FILE__)
    set :public_folder do "#{root}/assets" end
    set :views do "#{root}/views" end

    use Rack::Auth::Basic, "Restricted Area", &Tailog.basic_auth

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
