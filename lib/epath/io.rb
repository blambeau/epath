class Path
  #
  # #each_line iterates over the line in the file.  It yields a String object
  # for each line.
  #
  def each_line(*args, &block) # :yield: line
    IO.foreach(@path, *args, &block)
  end

  # See <tt>IO.read</tt>.  Returns all data from the file, or the first +N+ bytes
  # if specified.
  def read(*args) IO.read(@path, *args) end

  # See <tt>IO.binread</tt>.  Returns all the bytes from the file, or the first +N+
  # if specified.
  def binread(*args) IO.binread(@path, *args) end

  # See <tt>IO.readlines</tt>.  Returns all the lines from the file.
  def readlines(*args) IO.readlines(@path, *args) end

  # See <tt>IO.sysopen</tt>.
  def sysopen(*args) IO.sysopen(@path, *args) end

  def write(contents, open_args = nil)
    if IO.respond_to? :write
      IO.write(@path, contents, *[open_args].compact)
    else
      open('w', *[open_args].compact) { |f| f.write(contents) }
    end
  end

  def append(contents, open_args = nil)
    if IO.respond_to? :write
      open_args = (Array(open_args) << {:mode => 'a'})
      IO.write(@path, contents, *open_args.compact)
    else
      open('a', *[open_args].compact) { |f| f.write(contents) }
    end
  end
end