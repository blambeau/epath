# Path - a Path manipulation library

Dir.glob(File.expand_path('../epath/*.rb',__FILE__)) { |file| require file }

require 'tempfile'

class Path
  class << self
    # {Path} to the current file +Path(__FILE__)+.
    def file(from = nil)
      from ||= caller # this can not be moved as a default argument, JRuby optimizes it
                                     # v This : is there to define a group without capturing
      new(from.first.rpartition(/:\d+(?:$|:in )/).first).expand
    end
    alias :here :file

    # {Path} to the directory of this file: +Path(__FILE__).dir+.
    def dir(from = nil)
      from ||= caller # this can not be moved as a default argument, JRuby optimizes it
      file(from).dir
    end

    # {Path} relative to the directory of this file.
    def relative(path, from = nil)
      from ||= caller # this can not be moved as a default argument, JRuby optimizes it
      new(path).expand dir(from)
    end

    # A {Path} to the home directory of +user+ (defaults to the current user).
    # The form with an argument (+user+) is not supported on Windows.
    def ~(user = '')
      new("~#{user}")
    end
    alias :home :~

    # Same as +Path.file.backfind(path)+. See {#backfind}.
    def backfind(path)
      file(caller).backfind(path)
    end

    # @yieldparam [Path] tmpfile
    def tmpfile(basename = '', tmpdir = nil, options = nil)
      tempfile = Tempfile.new(basename, *[tmpdir, options].compact)
      file = new tempfile
      if block_given?
        begin
          yield file
        ensure
          tempfile.close!
        end
      end
      file
    end
    alias :tempfile :tmpfile

    # @yieldparam [Path] tmpdir
    def tmpdir(prefix_suffix = nil, *rest)
      require 'tmpdir'
      dir = new Dir.mktmpdir(prefix_suffix, *rest)
      if block_given?
        begin
          yield dir
        ensure
          FileUtils.remove_entry_secure(dir) rescue nil
        end
      end
      dir
    end

    # @yieldparam [Path] tmpdir
    def tmpchdir(prefix_suffix = nil, *rest)
      tmpdir do |dir|
        dir.chdir do
          yield dir
        end
      end
    end
  end

  # Whether +self+ is inside +ancestor+, such that +ancestor+ is an ancestor of +self+.
  # This is pure String manipulation. Paths should be absolute.
  def inside? ancestor
    @path == ancestor.to_s or @path.start_with?("#{ancestor}/")
  end

  # The opposite of {#inside?}.
  def outside? ancestor
    !inside?(ancestor)
  end

  # Ascends the parents until it finds the given +path+.
  #
  #   Path.backfind('lib') # => the lib folder
  #
  # It accepts an XPath-like context:
  #
  #   Path.backfind('.[.git]') # => the root of the repository
  def backfind(path)
    condition = path[/\[(.*)\]$/, 1] || ''
    path = $` unless condition.empty?

    result = ancestors.find { |ancestor| (ancestor/path/condition).exist? }
    result/path if result
  end

  # Setup
  register_loader 'yml', 'yaml' do |path|
    require 'yaml'
    YAML.load_file(path)
  end

  register_loader 'json' do |path|
    require 'json'
    JSON.load(path.read)
  end

  register_loader 'gemspec' do |path|
    eval path.read
  end
end

EPath = Path # to meet everyone's expectations
