module Bash
  def self.evaluate_string script
    output = []

    Open3.popen3("bash -x -e") do |stdin, stdout, stderr, wait_thr|
      Thread.new do until (line = stdout.gets).nil? do output << [ :stdout, line ] end end
      Thread.new do until (line = stderr.gets).nil? do output << [ :stderr, line ] end end

      stdin.puts script
      stdin.puts "exit"

      wait_thr.join
    end

    output.map do |key, line|
      if key == :stderr && line =~ /^\+ (.*)/
        [:stdin, line]
      else
        [key, line]
      end
    end
  end
end
