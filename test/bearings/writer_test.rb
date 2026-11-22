# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'tmpdir'

describe Bearings::Writer do
  before do
    @tmp = Dir.mktmpdir
    @site = File.join(@tmp, '_site')
  end

  after { FileUtils.remove_entry(@tmp) }

  def text(path, content = 'text')
    Bearings::OutputFile.new(path:, content:)
  end

  def leave(path)
    target = File.join(@site, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, 'old')
  end

  describe '.call' do
    it 'reports each path two or more output files share as an error' do
      problem = Bearings::Problem.new(
        check: 'output',
        level: :error,
        file: 'index.html',
        line: 1,
        message: '3 output files have this path',
        hint: 'give each output its own path'
      )
      files = [text('index.html'), text('index.html'), text('index.html'), text('a.html')]

      assert_equal [problem], Bearings::Writer.call(files, @site)
    end

    it 'leaves the disk untouched when output files share a path' do
      leave('stale.html')
      Bearings::Writer.call([text('index.html'), text('index.html')], @site)

      assert_equal ['stale.html'], Dir.children(@site)
    end

    it 'reports no problems when every path is distinct' do
      assert_empty Bearings::Writer.call([text('index.html'), text('a.html')], @site)
    end

    it 'replaces a stale file with the folder a new path needs' do
      leave('guide')
      Bearings::Writer.call([text('guide/index.html', 'new')], @site)

      assert_equal 'new', File.read(File.join(@site, 'guide/index.html'))
    end

    it 'removes a file left by an earlier build that is no longer produced' do
      leave('old.html')
      Bearings::Writer.call([text('index.html')], @site)

      refute_path_exists File.join(@site, 'old.html')
    end

    it 'removes a hidden file left by an earlier build' do
      leave('.old')
      Bearings::Writer.call([text('index.html')], @site)

      refute_path_exists File.join(@site, '.old')
    end

    it 'removes a folder the stale-file removal leaves empty' do
      leave('old/deep/page.html')
      Bearings::Writer.call([text('index.html')], @site)

      refute_path_exists File.join(@site, 'old')
    end

    it 'keeps a folder that still holds a produced file' do
      leave('guides/index.html')
      Bearings::Writer.call([text('guides/index.html', 'new')], @site)

      assert_equal 'new', File.read(File.join(@site, 'guides/index.html'))
    end

    it 'writes text content, creating folders as needed' do
      Bearings::Writer.call([text('guides/start/index.html', '<h1>Start</h1>')], @site)

      assert_equal '<h1>Start</h1>', File.read(File.join(@site, 'guides/start/index.html'))
    end

    it 'copies a source file' do
      source = File.join(@tmp, 'logo.png')
      png = "\x89PNG\x00\xFF".b
      File.binwrite(source, png)
      Bearings::Writer.call([Bearings::OutputFile.new(path: 'images/logo.png', content: Pathname(source))], @site)

      assert_equal png, File.binread(File.join(@site, 'images/logo.png'))
    end
  end
end
