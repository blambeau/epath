require 'spec_helper'

describe 'Path : File', :tmpchdir do
  dosish_drive_letter = File.dirname('A:') == 'A:.'

  let(:path) {
    path = Path('a')
    path.write 'abc'
    path
  }

  it 'atime, ctime, mtime' do
    Path(__FILE__).atime.should be_kind_of Time
    Path(__FILE__).ctime.should be_kind_of Time
    Path(__FILE__).mtime.should be_kind_of Time
  end

  it 'chmod' do
    old = path.stat.mode
    path.chmod(0444)
    (path.stat.mode & 0777).should == 0444
    path.chmod(old)
  end

  it 'lchmod', :symlink, :fails_on => [:rbx, :rbx19, :jruby, :jruby19] do
    link = Path('l').make_symlink(path)
    old = link.lstat.mode
    begin
      link.lchmod(0444)
    rescue NotImplementedError
      next
    end
    (link.lstat.mode & 0777).should == 0444
    link.chmod(old)
  end

  it 'chown', :fails_on => [:rbx, :rbx19, :jruby, :jruby19] do
    old_uid = path.stat.uid
    old_gid = path.stat.gid
    begin
      path.chown(0, 0)
    rescue Errno::EPERM
      next
    end
    path.stat.uid.should == 0
    path.stat.gid.should == 0
    path.chown(old_uid, old_gid)
  end

  it 'lchown', :symlink, :fails_on => [:rbx, :rbx19, :jruby, :jruby19] do
    link = Path('l').make_symlink(path)
    old_uid = link.stat.uid
    old_gid = link.stat.gid
    begin
      link.lchown(0, 0)
    rescue Errno::EPERM
      next
    end
    link.stat.uid.should == 0
    link.stat.gid.should == 0
    link.lchown(old_uid, old_gid)
  end

  it 'ftype' do
    path.ftype.should == 'file'
    Path('d').mkdir.ftype.should == 'directory'
  end

  it 'make_link', :fails_on => [:jruby, :jruby19, :rbx] do
    link = Path('link')
    link.make_link(path)
    # rbx18: https://github.com/rubinius/rubinius/pull/1754
    link.should be_identical(path)
    link.read.should == 'abc'
  end

  it 'readlink', :symlink, :fails_on => [:jruby, :jruby19] do
    Path('l').make_symlink(path).readlink.should == path
  end

  it 'rename' do
    path.rename('b').should == Path('b')
    Path('b').read.should == 'abc'
  end

  it 'stat' do
    path.stat.size.should == 3
  end

  it 'lstat', :symlink do
    link = Path('l').make_symlink(path)
    link.lstat.should be_a_symlink
    link.stat.should_not be_a_symlink
    link.stat.size.should == 3
    path.lstat.should_not be_a_symlink
    path.lstat.size.should == 3
  end

  it 'size' do
    path.size.should == 3

    Path('z').touch.size.should == 0
    expect { Path('not-exist').size }.to raise_error(Errno::ENOENT)
  end

  it 'make_symlink', :symlink do
    Path('l').make_symlink(path).lstat.should be_a_symlink
  end

  it 'truncate' do
    path.truncate 2
    path.size.should == 2
    path.read.should == 'ab'
  end

  it 'utime' do
    atime, mtime = Time.utc(2000), Time.utc(1999)
    path.utime(atime, mtime)
    path.stat.atime.should be_within(time_delta).of(atime)
    path.stat.mtime.should be_within(time_delta).of(mtime)
  end

  it 'expand, expand_path' do
    :expand.should be_an_alias_of :expand_path
    r = dosish_drive_letter ? Dir.pwd.sub(/\/.*/, '') : ''
    Path('/a').expand_path.to_s.should == r+'/a'
    Path('a').expand('/').to_s.should == r+'/a'
    Path('a').expand(Path('/')).to_s.should == r+'/a'
    Path('/b').expand(Path('/a')).to_s.should == r+'/b'
    Path('b').expand(Path('/a')).to_s.should == r+'/a/b'
  end
end
