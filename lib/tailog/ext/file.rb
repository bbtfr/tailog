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
