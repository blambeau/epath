class Path
  class << self
    # @!group Identity

    # Creates a new Path. See {#initialize}.
    def new(*args)
      if args.size == 1 and Path === args[0]
        args[0]
      else
        super(*args)
      end
    end
    alias :[] :new

    # A class constructor.
    #
    #   %w[foo bar].map(&Path) # == [Path('foo'), Path('bar')]
    def to_proc
      lambda { |path| new(path) }
    end
  end

  # @!group Identity

  # Compare this path with +other+. The comparison is string-based.
  # Be aware that two different paths (+foo.txt+ and +./foo.txt+)
  # can refer to the same file.
  def == other
    Path === other and @path == other.to_path
  end
  alias :eql? :==

  # Provides for comparing paths, case-sensitively.
  def <=>(other)
    return nil unless Path === other
    @path.tr('/', "\0") <=> other.to_s.tr('/', "\0")
  end

  # The hash value of the +path+.
  def hash
    @path.hash
  end

  # Returns the +path+ as a String.
  def to_s
    @path
  end

  # to_path is implemented so Path objects are usable with File.open, etc.
  alias :to_path :to_s

  # to_str is implemented so Path objects are usable with File.open, etc in Ruby 1.8.
  alias :to_str :to_s if RUBY_VERSION < '1.9'

  # Returns the +path+ as a Symbol.
  def to_sym
    @path.to_sym
  end

  # A representation of the +path+.
  def inspect
    "#<Path #{@path}>"
  end
end

unless defined? NO_EPATH_GLOBAL_FUNCTION
  # A shorthand method to create a {Path}. Same as {Path.new}.
  def Path(*args)
    Path.new(*args)
  end
end
