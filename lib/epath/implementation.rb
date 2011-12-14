# Path's low-level implementation based on Pathname

require 'fileutils'

class Path
  # :stopdoc:
  SAME_PATHS = if File::FNM_SYSCASE.nonzero?
    proc {|a, b| a.casecmp(b).zero?}
  else
    proc {|a, b| a == b}
  end

  # :startdoc:

  def freeze() super; @path.freeze; self end
  def taint() super; @path.taint; self end
  def untaint() super; @path.untaint; self end

  #
  # Compare this pathname with +other+.  The comparison is string-based.
  # Be aware that two different paths (<tt>foo.txt</tt> and <tt>./foo.txt</tt>)
  # can refer to the same file.
  #
  def == other
    Path === other and @path == other.to_s
  end
  alias eql? ==

  # Provides for comparing pathnames, case-sensitively.
  def <=>(other)
    return nil unless Path === other
    @path.tr('/', "\0") <=> other.to_s.tr('/', "\0")
  end

  def hash # :nodoc:
    @path.hash
  end

  # Return the path as a String.
  def to_s
    @path.dup
  end

  # to_path is implemented so Path objects are usable with File.open, etc.
  alias to_path to_s

  alias to_str to_s if RUBY_VERSION < '1.9'

  def inspect
    "#<Path #{@path}>"
  end

  # Return a pathname which is substituted by String#sub.
  def sub(pattern, *rest, &block)
    if block
      path = @path.sub(pattern, *rest) {|*args|
        begin
          old = Thread.current[:pathname_sub_matchdata]
          Thread.current[:pathname_sub_matchdata] = $~
          eval("$~ = Thread.current[:pathname_sub_matchdata]", block.binding)
        ensure
          Thread.current[:pathname_sub_matchdata] = old
        end
        yield(*args)
      }
    else
      path = @path.sub(pattern, *rest)
    end
    Path.new(path)
  end

  if File::ALT_SEPARATOR
    SEPARATOR_LIST = "#{Regexp.quote File::ALT_SEPARATOR}#{Regexp.quote File::SEPARATOR}"
    SEPARATOR_PAT = /[#{SEPARATOR_LIST}]/
  else
    SEPARATOR_LIST = "#{Regexp.quote File::SEPARATOR}"
    SEPARATOR_PAT = /#{Regexp.quote File::SEPARATOR}/
  end

  # Return a pathname which the extension of the basename is substituted by
  # <i>repl</i>.
  #
  # If self has no extension part, <i>repl</i> is appended.
  def sub_ext(repl)
    ext = File.extname(@path)
    Path.new(@path.chomp(ext) + repl)
  end

  # chop_basename(path) -> [pre-basename, basename] or nil
  def chop_basename(path)
    base = File.basename(path)
    if /\A#{SEPARATOR_PAT}?\z/o =~ base
      return nil
    else
      return path[0, path.rindex(base)], base
    end
  end
  private :chop_basename

  # split_names(path) -> prefix, [name, ...]
  def split_names(path)
    names = []
    while r = chop_basename(path)
      path, basename = r
      names.unshift basename
    end
    return path, names
  end
  private :split_names

  def prepend_prefix(prefix, relpath)
    if relpath.empty?
      File.dirname(prefix)
    elsif /#{SEPARATOR_PAT}/o =~ prefix
      prefix = File.dirname(prefix)
      prefix = File.join(prefix, "") if File.basename(prefix + 'a') != 'a'
      prefix + relpath
    else
      prefix + relpath
    end
  end
  private :prepend_prefix

  # Returns clean pathname of +self+ with consecutive slashes and useless dots
  # removed.  The filesystem is not accessed.
  #
  # If +consider_symlink+ is +true+, then a more conservative algorithm is used
  # to avoid breaking symbolic linkages.  This may retain more <tt>..</tt>
  # entries than absolutely necessary, but without accessing the filesystem,
  # this can't be avoided.  See #realpath.
  #
  def cleanpath(consider_symlink=false)
    if consider_symlink
      cleanpath_conservative
    else
      cleanpath_aggressive
    end
  end

  #
  # Clean the path simply by resolving and removing excess "." and ".." entries.
  # Nothing more, nothing less.
  #
  def cleanpath_aggressive
    path = @path
    names = []
    pre = path
    while r = chop_basename(pre)
      pre, base = r
      case base
      when '.'
      when '..'
        names.unshift base
      else
        if names[0] == '..'
          names.shift
        else
          names.unshift base
        end
      end
    end
    if /#{SEPARATOR_PAT}/o =~ File.basename(pre)
      names.shift while names[0] == '..'
    end
    Path.new(prepend_prefix(pre, File.join(*names)))
  end
  private :cleanpath_aggressive

  # has_trailing_separator?(path) -> bool
  def has_trailing_separator?(path)
    if r = chop_basename(path)
      pre, basename = r
      pre.length + basename.length < path.length
    else
      false
    end
  end
  private :has_trailing_separator?

  # add_trailing_separator(path) -> path
  def add_trailing_separator(path)
    if File.basename(path + 'a') == 'a'
      path
    else
      File.join(path, "") # xxx: Is File.join is appropriate to add separator?
    end
  end
  private :add_trailing_separator

  def del_trailing_separator(path)
    if r = chop_basename(path)
      pre, basename = r
      pre + basename
    elsif /#{SEPARATOR_PAT}+\z/o =~ path
      $` + File.dirname(path)[/#{SEPARATOR_PAT}*\z/o]
    else
      path
    end
  end
  private :del_trailing_separator

  def cleanpath_conservative
    path = @path
    names = []
    pre = path
    while r = chop_basename(pre)
      pre, base = r
      names.unshift base if base != '.'
    end
    if /#{SEPARATOR_PAT}/o =~ File.basename(pre)
      names.shift while names[0] == '..'
    end
    if names.empty?
      Path.new(File.dirname(pre))
    else
      if names.last != '..' && File.basename(path) == '.'
        names << '.'
      end
      result = prepend_prefix(pre, File.join(*names))
      if /\A(?:\.|\.\.)\z/ !~ names.last && has_trailing_separator?(path)
        Path.new(add_trailing_separator(result))
      else
        Path.new(result)
      end
    end
  end
  private :cleanpath_conservative

  #
  # Returns the real (absolute) pathname of +self+ in the actual
  # filesystem not containing symlinks or useless dots.
  #
  # All components of the pathname must exist when this method is
  # called.
  #
  def realpath(basedir=nil)
    Path.new(File.realpath(@path, basedir))
  end

  #
  # Returns the real (absolute) pathname of +self+ in the actual filesystem.
  # The real pathname doesn't contain symlinks or useless dots.
  #
  # The last component of the real pathname can be nonexistent.
  #
  def realdirpath(basedir=nil)
    Path.new(File.realdirpath(@path, basedir))
  end

  # #parent returns the parent directory.
  #
  # This is same as <tt>self + '..'</tt>.
  def parent
    self + '..'
  end

  # #mountpoint? returns +true+ if <tt>self</tt> points to a mountpoint.
  def mountpoint?
    begin
      stat1 = self.lstat
      stat2 = self.parent.lstat
      stat1.dev == stat2.dev && stat1.ino == stat2.ino ||
        stat1.dev != stat2.dev
    rescue Errno::ENOENT
      false
    end
  end

  #
  # #root? is a predicate for root directories.  I.e. it returns +true+ if the
  # pathname consists of consecutive slashes.
  #
  # It doesn't access actual filesystem.  So it may return +false+ for some
  # pathnames which points to roots such as <tt>/usr/..</tt>.
  #
  def root?
    !!(chop_basename(@path) == nil && /#{SEPARATOR_PAT}/o =~ @path)
  end

  # Predicate method for testing whether a path is absolute.
  # It returns +true+ if the pathname begins with a slash.
  def absolute?
    !relative?
  end

  # The opposite of #absolute?
  def relative?
    path = @path
    while r = chop_basename(path)
      path, = r
    end
    path == ''
  end

  #
  # Iterates over each component of the path.
  #
  #   Path.new("/usr/bin/ruby").each_filename {|filename| ... }
  #     # yields "usr", "bin", and "ruby".
  #
  def each_filename # :yield: filename
    return to_enum(__method__) unless block_given?
    _, names = split_names(@path)
    names.each {|filename| yield filename }
    nil
  end

  # Iterates over and yields a new Path object
  # for each element in the given path in descending order.
  #
  #  Path.new('/path/to/some/file.rb').descend {|v| p v}
  #     #<Path:/>
  #     #<Path:/path>
  #     #<Path:/path/to>
  #     #<Path:/path/to/some>
  #     #<Path:/path/to/some/file.rb>
  #
  #  Path.new('path/to/some/file.rb').descend {|v| p v}
  #     #<Path:path>
  #     #<Path:path/to>
  #     #<Path:path/to/some>
  #     #<Path:path/to/some/file.rb>
  #
  # It doesn't access actual filesystem.
  #
  # This method is available since 1.8.5.
  #
  def descend
    vs = []
    ascend {|v| vs << v }
    vs.reverse_each {|v| yield v }
    nil
  end

  # Iterates over and yields a new Path object
  # for each element in the given path in ascending order.
  #
  #  Path.new('/path/to/some/file.rb').ascend {|v| p v}
  #     #<Path:/path/to/some/file.rb>
  #     #<Path:/path/to/some>
  #     #<Path:/path/to>
  #     #<Path:/path>
  #     #<Path:/>
  #
  #  Path.new('path/to/some/file.rb').ascend {|v| p v}
  #     #<Path:path/to/some/file.rb>
  #     #<Path:path/to/some>
  #     #<Path:path/to>
  #     #<Path:path>
  #
  # It doesn't access actual filesystem.
  #
  # This method is available since 1.8.5.
  #
  def ascend
    path = @path
    yield self
    while r = chop_basename(path)
      path, = r
      break if path.empty?
      yield Path.new(del_trailing_separator(path))
    end
  end

  #
  # Path#+ appends a pathname fragment to this one to produce a new Path
  # object.
  #
  #   p1 = Path.new("/usr")      # Path:/usr
  #   p2 = p1 + "bin/ruby"           # Path:/usr/bin/ruby
  #   p3 = p1 + "/etc/passwd"        # Path:/etc/passwd
  #
  # This method doesn't access the file system; it is pure string manipulation.
  #
  def +(other)
    other = Path.new(other) unless Path === other
    Path.new(plus(@path, other.to_s))
  end

  def plus(path1, path2) # -> path
    prefix2 = path2
    index_list2 = []
    basename_list2 = []
    while r2 = chop_basename(prefix2)
      prefix2, basename2 = r2
      index_list2.unshift prefix2.length
      basename_list2.unshift basename2
    end
    return path2 if prefix2 != ''
    prefix1 = path1
    while true
      while !basename_list2.empty? && basename_list2.first == '.'
        index_list2.shift
        basename_list2.shift
      end
      break unless r1 = chop_basename(prefix1)
      prefix1, basename1 = r1
      next if basename1 == '.'
      if basename1 == '..' || basename_list2.empty? || basename_list2.first != '..'
        prefix1 = prefix1 + basename1
        break
      end
      index_list2.shift
      basename_list2.shift
    end
    r1 = chop_basename(prefix1)
    if !r1 && /#{SEPARATOR_PAT}/o =~ File.basename(prefix1)
      while !basename_list2.empty? && basename_list2.first == '..'
        index_list2.shift
        basename_list2.shift
      end
    end
    if !basename_list2.empty?
      suffix2 = path2[index_list2.first..-1]
      r1 ? File.join(prefix1, suffix2) : prefix1 + suffix2
    else
      r1 ? prefix1 : File.dirname(prefix1)
    end
  end
  private :plus

  #
  # Path#join joins pathnames.
  #
  # <tt>path0.join(path1, ..., pathN)</tt> is the same as
  # <tt>path0 + path1 + ... + pathN</tt>.
  #
  def join(*args)
    args.unshift self
    result = args.pop
    result = Path.new(result) unless Path === result
    return result if result.absolute?
    args.reverse_each {|arg|
      arg = Path.new(arg) unless Path === arg
      result = arg + result
      return result if result.absolute?
    }
    result
  end

  #
  # Returns the children of the directory (files and subdirectories, not
  # recursive) as an array of Path objects.  By default, the returned
  # pathnames will have enough information to access the files.  If you set
  # +with_directory+ to +false+, then the returned pathnames will contain the
  # filename only.
  #
  # For example:
  #   pn = Path("/usr/lib/ruby/1.8")
  #   pn.children
  #       # -> [ Path:/usr/lib/ruby/1.8/English.rb,
  #              Path:/usr/lib/ruby/1.8/Env.rb,
  #              Path:/usr/lib/ruby/1.8/abbrev.rb, ... ]
  #   pn.children(false)
  #       # -> [ Path:English.rb, Path:Env.rb, Path:abbrev.rb, ... ]
  #
  # Note that the results never contain the entries <tt>.</tt> and <tt>..</tt> in
  # the directory because they are not children.
  #
  # This method has existed since 1.8.1.
  #
  def children(with_directory=true)
    with_directory = false if @path == '.'
    result = []
    Dir.foreach(@path) {|e|
      next if e == '.' || e == '..'
      if with_directory
        result << Path.new(File.join(@path, e))
      else
        result << Path.new(e)
      end
    }
    result
  end

  # Iterates over the children of the directory
  # (files and subdirectories, not recursive).
  # It yields Path object for each child.
  # By default, the yielded pathnames will have enough information to access the files.
  # If you set +with_directory+ to +false+, then the returned pathnames will contain the filename only.
  #
  #   Path("/usr/local").each_child {|f| p f }
  #   #=> #<Path:/usr/local/share>
  #   #   #<Path:/usr/local/bin>
  #   #   #<Path:/usr/local/games>
  #   #   #<Path:/usr/local/lib>
  #   #   #<Path:/usr/local/include>
  #   #   #<Path:/usr/local/sbin>
  #   #   #<Path:/usr/local/src>
  #   #   #<Path:/usr/local/man>
  #
  #   Path("/usr/local").each_child(false) {|f| p f }
  #   #=> #<Path:share>
  #   #   #<Path:bin>
  #   #   #<Path:games>
  #   #   #<Path:lib>
  #   #   #<Path:include>
  #   #   #<Path:sbin>
  #   #   #<Path:src>
  #   #   #<Path:man>
  #
  def each_child(with_directory=true, &b)
    children(with_directory).each(&b)
  end

  #
  # #relative_path_from returns a relative path from the argument to the
  # receiver.  If +self+ is absolute, the argument must be absolute too.  If
  # +self+ is relative, the argument must be relative too.
  #
  # #relative_path_from doesn't access the filesystem.  It assumes no symlinks.
  #
  # ArgumentError is raised when it cannot find a relative path.
  #
  # This method has existed since 1.8.1.
  #
  def relative_path_from(base_directory)
    dest_directory = self.cleanpath.to_s
    base_directory = base_directory.cleanpath.to_s
    dest_prefix = dest_directory
    dest_names = []
    while r = chop_basename(dest_prefix)
      dest_prefix, basename = r
      dest_names.unshift basename if basename != '.'
    end
    base_prefix = base_directory
    base_names = []
    while r = chop_basename(base_prefix)
      base_prefix, basename = r
      base_names.unshift basename if basename != '.'
    end
    unless SAME_PATHS[dest_prefix, base_prefix]
      raise ArgumentError, "different prefix: #{dest_prefix.inspect} and #{base_directory.inspect}"
    end
    while !dest_names.empty? &&
          !base_names.empty? &&
          SAME_PATHS[dest_names.first, base_names.first]
      dest_names.shift
      base_names.shift
    end
    if base_names.include? '..'
      raise ArgumentError, "base_directory has ..: #{base_directory.inspect}"
    end
    base_names.fill('..')
    relpath_names = base_names + dest_names
    if relpath_names.empty?
      Path.new('.')
    else
      Path.new(File.join(*relpath_names))
    end
  end
end

class Path    # * IO *
  #
  # #each_line iterates over the line in the file.  It yields a String object
  # for each line.
  #
  # This method has existed since 1.8.1.
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
end


class Path    # * File *

  # See <tt>File.atime</tt>.  Returns last access time.
  def atime() File.atime(@path) end

  # See <tt>File.ctime</tt>.  Returns last (directory entry, not file) change time.
  def ctime() File.ctime(@path) end

  # See <tt>File.mtime</tt>.  Returns last modification time.
  def mtime() File.mtime(@path) end

  # See <tt>File.chmod</tt>.  Changes permissions.
  def chmod(mode) File.chmod(mode, @path) end

  # See <tt>File.lchmod</tt>.
  def lchmod(mode) File.lchmod(mode, @path) end

  # See <tt>File.chown</tt>.  Change owner and group of file.
  def chown(owner, group) File.chown(owner, group, @path) end

  # See <tt>File.lchown</tt>.
  def lchown(owner, group) File.lchown(owner, group, @path) end

  # See <tt>File.fnmatch</tt>.  Return +true+ if the receiver matches the given
  # pattern.
  def fnmatch(pattern, *args) File.fnmatch(pattern, @path, *args) end

  # See <tt>File.fnmatch?</tt> (same as #fnmatch).
  def fnmatch?(pattern, *args) File.fnmatch?(pattern, @path, *args) end

  # See <tt>File.ftype</tt>.  Returns "type" of file ("file", "directory",
  # etc).
  def ftype() File.ftype(@path) end

  # See <tt>File.link</tt>.  Creates a hard link.
  def make_link(old) File.link(old, @path) end

  # See <tt>File.open</tt>.  Opens the file for reading or writing.
  def open(*args, &block) # :yield: file
    File.open(@path, *args, &block)
  end

  # See <tt>File.readlink</tt>.  Read symbolic link.
  def readlink() Path.new(File.readlink(@path)) end

  # See <tt>File.rename</tt>.  Rename the file.
  def rename(to) File.rename(@path, to) end

  # See <tt>File.stat</tt>.  Returns a <tt>File::Stat</tt> object.
  def stat() File.stat(@path) end

  # See <tt>File.lstat</tt>.
  def lstat() File.lstat(@path) end

  # See <tt>File.symlink</tt>.  Creates a symbolic link.
  def make_symlink(old) File.symlink(old, @path) end

  # See <tt>File.truncate</tt>.  Truncate the file to +length+ bytes.
  def truncate(length) File.truncate(@path, length) end

  # See <tt>File.utime</tt>.  Update the access and modification times.
  def utime(atime, mtime) File.utime(atime, mtime, @path) end

  # See <tt>File.basename</tt>.  Returns the last component of the path.
  def basename(*args) Path.new(File.basename(@path, *args)) end

  # See <tt>File.dirname</tt>.  Returns all but the last component of the path.
  def dirname() Path.new(File.dirname(@path)) end

  # See <tt>File.extname</tt>.  Returns the file's extension.
  def extname() File.extname(@path) end

  # See <tt>File.expand_path</tt>.
  def expand_path(*args) Path.new(File.expand_path(@path, *args)) end

  # See <tt>File.split</tt>.  Returns the #dirname and the #basename in an
  # Array.
  def split() File.split(@path).map {|f| Path.new(f) } end
end


class Path    # * FileTest *

  # See <tt>FileTest.blockdev?</tt>.
  def blockdev?() FileTest.blockdev?(@path) end

  # See <tt>FileTest.chardev?</tt>.
  def chardev?() FileTest.chardev?(@path) end

  # See <tt>FileTest.executable?</tt>.
  def executable?() FileTest.executable?(@path) end

  # See <tt>FileTest.executable_real?</tt>.
  def executable_real?() FileTest.executable_real?(@path) end

  # See <tt>FileTest.exist?</tt>.
  def exist?() FileTest.exist?(@path) end

  # See <tt>FileTest.grpowned?</tt>.
  def grpowned?() FileTest.grpowned?(@path) end

  # See <tt>FileTest.directory?</tt>.
  def directory?() FileTest.directory?(@path) end

  # See <tt>FileTest.file?</tt>.
  def file?() FileTest.file?(@path) end

  # See <tt>FileTest.pipe?</tt>.
  def pipe?() FileTest.pipe?(@path) end

  # See <tt>FileTest.socket?</tt>.
  def socket?() FileTest.socket?(@path) end

  # See <tt>FileTest.owned?</tt>.
  def owned?() FileTest.owned?(@path) end

  # See <tt>FileTest.readable?</tt>.
  def readable?() FileTest.readable?(@path) end

  # See <tt>FileTest.world_readable?</tt>.
  def world_readable?() FileTest.world_readable?(@path) end

  # See <tt>FileTest.readable_real?</tt>.
  def readable_real?() FileTest.readable_real?(@path) end

  # See <tt>FileTest.setuid?</tt>.
  def setuid?() FileTest.setuid?(@path) end

  # See <tt>FileTest.setgid?</tt>.
  def setgid?() FileTest.setgid?(@path) end

  # See <tt>FileTest.size</tt>.
  def size() FileTest.size(@path) end

  # See <tt>FileTest.size?</tt>.
  def size?() FileTest.size?(@path) end

  # See <tt>FileTest.sticky?</tt>.
  def sticky?() FileTest.sticky?(@path) end

  # See <tt>FileTest.symlink?</tt>.
  def symlink?() FileTest.symlink?(@path) end

  # See <tt>FileTest.writable?</tt>.
  def writable?() FileTest.writable?(@path) end

  # See <tt>FileTest.world_writable?</tt>.
  def world_writable?() FileTest.world_writable?(@path) end

  # See <tt>FileTest.writable_real?</tt>.
  def writable_real?() FileTest.writable_real?(@path) end

  # See <tt>FileTest.zero?</tt>.
  def zero?() FileTest.zero?(@path) end
end


class Path    # * Dir *
  # See <tt>Dir.glob</tt>.  Returns or yields Path objects.
  def Path.glob(*args) # :yield: pathname
    if block_given?
      Dir.glob(*args) {|f| yield self.new(f) }
    else
      Dir.glob(*args).map {|f| self.new(f) }
    end
  end

  # See <tt>Dir.getwd</tt>.  Returns the current working directory as a Path.
  def Path.getwd() self.new(Dir.getwd) end
  class << self; alias pwd getwd end

  # Iterates over the entries (files and subdirectories) in the directory.  It
  # yields a Path object for each entry.
  #
  # This method has existed since 1.8.1.
  def each_entry(&block) # :yield: pathname
    Dir.foreach(@path) {|f| yield Path.new(f) }
  end

  # See <tt>Dir.mkdir</tt>.  Create the referenced directory.
  def mkdir(*args) Dir.mkdir(@path, *args) end

  # See <tt>Dir.rmdir</tt>.  Remove the referenced directory.
  def rmdir() Dir.rmdir(@path) end

  # See <tt>Dir.open</tt>.
  def opendir(&block) # :yield: dir
    Dir.open(@path, &block)
  end
end


class Path    # * Find *
  #
  # Path#find is an iterator to traverse a directory tree in a depth first
  # manner.  It yields a Path for each file under "this" directory.
  #
  # Since it is implemented by <tt>find.rb</tt>, <tt>Find.prune</tt> can be used
  # to control the traversal.
  #
  # If +self+ is <tt>.</tt>, yielded pathnames begin with a filename in the
  # current directory, not <tt>./</tt>.
  #
  def find # :yield: pathname
    return to_enum(__method__) unless block_given?
    require 'find'
    if @path == '.'
      Find.find(@path) {|f| yield Path.new(f.sub(%r{\A\./}, '')) }
    else
      Find.find(@path) {|f| yield Path.new(f) }
    end
  end
end


class Path    # * FileUtils *
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
end


class Path    # * mixed *
  # Removes a file or directory, using <tt>File.unlink</tt> or
  # <tt>Dir.unlink</tt> as necessary.
  def unlink()
    begin
      Dir.unlink @path
    rescue Errno::ENOTDIR
      File.unlink @path
    end
  end
  alias delete unlink
end
