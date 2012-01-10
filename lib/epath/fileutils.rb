require 'fileutils'

class Path
  # See <tt>FileUtils.mkpath</tt>.  Creates a full path, including any
  # intermediate directories that don't yet exist.
  def mkpath
    FileUtils.mkpath(@path)
    nil
  end

  # See <tt>FileUtils.rm_r</tt>.  Deletes a directory and all beneath it.
  def rmtree
    # The name "rmtree" is borrowed from File::Path of Perl.
    # File::Path provides "mkpath" and "rmtree".
    FileUtils.rm_r(@path)
    nil
  end

  def rm
    FileUtils.rm(@path)
    self
  end

  def rm_f
    FileUtils.rm_f(@path)
    self
  end

  def rm_rf
    FileUtils.rm_rf(@path)
    self
  end

  def touch
    FileUtils.touch(@path)
    self
  end

  def mkdir_p
    FileUtils.mkdir_p(@path)
    self
  end
end