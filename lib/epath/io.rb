class Path
  # Opens the file for reading or writing. See +File.open+.
  def open(*args, &block) # :yield: file
    File.open(@path, *args, &block)
  end

  # Iterates over the lines in the file. See +IO.foreach+.
  def each_line(*args, &block) # :yield: line
    IO.foreach(@path, *args, &block)
  end
  alias :lines :each_line

  # Returns all data from the file, or the first +N+ bytes if specified.
  # See +IO.read+.
  def read(*args)
    IO.read(@path, *args)
  end

  # Returns all the bytes from the file, or the first +N+ if specified.
  # See +IO.binread+.
  if IO.respond_to? :binread
    def binread(*args)
      IO.binread(@path, *args)
    end
  else
    alias :binread :read
  end

  # Returns all the lines from the file. See +IO.readlines+.
  def readlines(*args)
    IO.readlines(@path, *args)
  end

  # See +IO.sysopen+.
  def sysopen(*args)
    IO.sysopen(@path, *args)
  end

  if IO.respond_to? :write
    def write(contents, *open_args)
      IO.write(@path, contents, *open_args)
    end
  else
    def write(contents, *open_args)
      open('w', *open_args) { |f| f.write(contents) }
    end
  end

  if IO.respond_to? :write
    def append(contents, open_args = {})
      open_args[:mode] = 'a'
      IO.write(@path, contents, open_args)
    end
  else
    def append(contents, open_args = nil)
      open('a') { |f| f.write(contents) }
    end
  end
end
