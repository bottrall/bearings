# frozen_string_literal: true

require 'test_helper'
require 'bearings/rake'
require 'fileutils'
require 'tmpdir'

describe Bearings::Rake do
  before do
    @tmp = Dir.mktmpdir
    Rake.application = Rake::Application.new
  end

  after do
    FileUtils.remove_entry(@tmp)
    ENV.delete('FORMAT')
  end

  def fixture(name) = File.join(__dir__, '..', 'fixtures', 'build', name)

  def tree(dir)
    Dir.glob('**/*', base: dir).reject { |path| File.directory?(File.join(dir, path)) }.sort
       .to_h { |path| [path, File.read(File.join(dir, path))] }
  end

  def http(results)
    Struct.new(:results) { def status(url) = results.fetch(url, 200) }.new(results)
  end

  def write(path, content)
    target = File.join(@tmp, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, content)
  end

  def delete(path) = File.delete(File.join(@tmp, path))

  def write_site = FileUtils.cp_r("#{fixture('repo')}/.", @tmp)

  def problem(check, level: :error)
    Bearings::Problem.new(check:, level:, file: 'docs/START.md', line: 1, message: 'is wrong', hint: nil)
  end

  def failing(level: :error) = ->(_) { [[], [problem('output', level:)]] }

  def flagging = ->(_, _) { [problem('check')] }

  def declared
    ->(input) { [[Bearings::OutputFile.new(path: 'declared', content: input.declared.to_a.join(','))], []] }
  end

  def run_task(task, results: {}, **lists)
    Bearings::Rake.install(http: http(results), **lists)
    status = 0
    output, = capture_io do
      Dir.chdir(@tmp) { Rake::Task[task].invoke }
    rescue SystemExit => e
      status = e.status
    end
    [output, status]
  end

  def output(...) = run_task(...).first

  def status(...) = run_task(...).last

  def built(...)
    run_task(...)
    tree(File.join(@tmp, '_site'))
  end

  def images
    lambda do |input|
      [[Bearings::OutputFile.new(path: 'images', content: input.images.map { |pair| pair.join('=') }.join(','))], []]
    end
  end

  def timed_out = Bearings::Checks::ExternalLinks::Failure.new(reason: 'timed out after 10s', timed_out: true)

  describe 'requiring bearings/rake' do
    it 'loads the gem and rake on its own' do
      lib = File.expand_path('../../lib', __dir__)
      script = 'require "bearings/rake"; print Bearings::Rake.method(:install).owner'

      assert_equal 'Bearings::Rake', IO.popen([RbConfig.ruby, '-I', lib, '-e', script], &:read)
    end
  end

  describe 'docs' do
    it 'reports a manifest that is not there' do
      assert_includes output('docs'), 'docs-site/manifest.yml:1: [manifest] was not found'
    end

    it 'reports the problems in a manifest that does not parse' do
      write('docs-site/manifest.yml', "site: {}\n")

      assert_includes output('docs'), 'the manifest is missing `groups`'
    end

    it 'leaves _site alone when the manifest does not parse' do
      write('docs-site/manifest.yml', "site: {}\n")
      write('_site/index.html', 'before')

      assert_equal({ 'index.html' => 'before' }, built('docs'))
    end

    it 'reports a missing source' do
      write_site
      delete('docs/reference/MANIFEST.md')

      assert_includes output('docs'),
                      'docs/reference/MANIFEST.md:1: [source] is listed in the manifest but was not found'
    end

    it 'writes the pages that built when a source is missing' do
      write_site
      delete('docs/reference/MANIFEST.md')

      assert_includes built('docs').keys, 'guides/start/index.html'
    end

    it 'reports a missing layout' do
      write_site
      delete('docs-site/layout.html.erb')

      assert_includes output('docs'), 'docs-site/layout.html.erb:1: [layout] was not found'
    end

    it 'reports a missing landing template' do
      write_site
      delete('docs-site/index.html.erb')

      assert_includes output('docs'), 'docs-site/index.html.erb:1: [layout] was not found'
    end

    it 'leaves the last build out of the assets when the manifest is at the repo root' do
      write_site
      FileUtils.cp_r("#{@tmp}/docs-site/.", @tmp)
      write('_site/index.html', 'before')

      refute(built('docs', manifest: 'manifest.yml').keys.any? { |path| path.start_with?('_site/') })
    end

    it 'gives the outputs the bytes of each image the guides use' do
      write_site

      assert_equal "images/flow.svg=#{File.read(File.join(fixture('repo'), 'images/flow.svg'))}",
                   built('docs', outputs: [images])['images']
    end

    it 'leaves an image whose file is missing out of what it gives the outputs' do
      write_site
      delete('images/flow.svg')

      assert_equal '', built('docs', outputs: [images])['images']
    end

    it 'gives the outputs the files in the watched folders' do
      write_site
      watched = ->(input) { [[Bearings::OutputFile.new(path: 'watched', content: input.watched.sort.join(','))], []] }

      assert_equal 'docs/START.md,docs/reference/MANIFEST.md', built('docs', outputs: [watched])['watched']
    end

    it 'gives the outputs the signatures sig/ declares when the site names namespaces' do
      write_site
      write(
        'docs-site/manifest.yml',
        File.read(File.join(@tmp, 'docs-site/manifest.yml')).sub('site:', "site:\n  namespaces: [Bearings]")
      )
      write('sig/bearings.rbs', "module Bearings\nend\n")

      assert_equal 'Bearings', built('docs', outputs: [declared])['declared']
    end

    it 'gives the outputs no declared signatures when the site names no namespaces' do
      write_site
      write('sig/bearings.rbs', "module Bearings\nend\n")

      assert_equal '', built('docs', outputs: [declared])['declared']
    end

    it 'builds the fixture site into _site' do
      write_site

      assert_equal tree(fixture('expected')), built('docs')
    end

    it 'runs the outputs it is given' do
      write_site
      a = ->(_) { [[Bearings::OutputFile.new(path: 'a.txt', content: 'A')], []] }

      assert_equal({ 'a.txt' => 'A' }, built('docs', outputs: [a]))
    end

    it 'runs none of the checks' do
      write_site

      assert_empty output('docs', checks: [flagging])
    end

    it 'reports the problems writing the files' do
      write_site
      twice = ->(_) { [Array.new(2) { Bearings::OutputFile.new(path: 'a.txt', content: 'A') }, []] }

      assert_includes output('docs', outputs: [twice]), 'a.txt:1: [output] 2 output files have this path'
    end

    it 'prints nothing when there are no problems' do
      write_site

      assert_empty output('docs')
    end

    it 'prints the problems as JSON when FORMAT is json' do
      write_site
      ENV['FORMAT'] = 'json'

      assert_equal(
        [{ 'check' => 'output', 'level' => 'error', 'file' => 'docs/START.md', 'line' => 1, 'message' => 'is wrong',
           'hint' => nil }],
        JSON.parse(output('docs', outputs: [failing]))
      )
    end

    it 'prints an empty JSON list when FORMAT is json and there are no problems' do
      write_site
      ENV['FORMAT'] = 'json'

      assert_equal "[]\n", output('docs')
    end

    it 'exits with status 1 when a problem is an error' do
      write_site

      assert_equal 1, status('docs', outputs: [failing])
    end

    it 'exits with status 0 when every problem is a warning' do
      write_site

      assert_equal 0, status('docs', outputs: [failing(level: :warning)])
    end
  end

  describe 'docs:check' do
    it 'builds the site' do
      write_site

      assert_equal tree(fixture('expected')), built('docs:check')
    end

    it 'passes the fixture site' do
      write_site

      assert_equal 0, status('docs:check')
    end

    it 'reports the problems from the checks' do
      write_site

      assert_includes output('docs:check', checks: [flagging]), 'docs/START.md:1: [check] is wrong'
    end

    it 'exits with status 1 when a check finds an error' do
      write_site

      assert_equal 1, status('docs:check', checks: [flagging])
    end
  end

  describe 'docs:check:external' do
    def write_external_site
      write_site
      write('docs/START.md', "# Start\n\nSee [the example](https://a.example).\n")
    end

    it 'reports a manifest that is not there' do
      assert_includes output('docs:check:external'), 'docs-site/manifest.yml:1: [manifest] was not found'
    end

    it 'reports the problems from building the site' do
      write_external_site
      delete('docs/reference/MANIFEST.md')

      assert_includes output('docs:check:external'),
                      'docs/reference/MANIFEST.md:1: [source] is listed in the manifest but was not found'
    end

    it 'checks the guides that build when another is missing' do
      write_external_site
      delete('docs/reference/MANIFEST.md')

      assert_includes output('docs:check:external', results: { 'https://a.example' => 404 }),
                      'docs/START.md:3: [external-links] https://a.example returned HTTP 404'
    end

    it 'prints nothing when there are no problems' do
      write_external_site

      assert_empty output('docs:check:external')
    end

    it 'exits with status 1 when a problem is an error' do
      write_external_site

      assert_equal 1, status('docs:check:external', results: { 'https://a.example' => 404 })
    end

    it 'exits with status 0 when every problem is a warning' do
      write_external_site

      assert_equal 0, status('docs:check:external', results: { 'https://a.example' => timed_out })
    end
  end
end
