require 'tailog/version'
require 'sinatra/base'

class File

  def tail(n)
    buffer = 1024
    idx = (size - buffer).abs
    chunks = []
    lines = 0

    begin
      seek(idx)
      chunk = read(buffer)
      break unless chunk
      lines += chunk.count("\n")
      chunks.unshift chunk
      idx -= buffer
    end while lines < ( n + 1 ) && pos != 0

    tail_of_file = chunks.join('')
    ary = tail_of_file.split(/\n/)
    lines_to_return = ary[ ary.size - n, ary.size - 1 ]

  end
end

module Tailog

  class << self
    attr_accessor :log_path
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
      if params[:seek]
        erb :ajax
      else
        erb :index
      end
    end
  end
end
