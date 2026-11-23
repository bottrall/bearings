# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'rake'
require 'tmpdir'

describe Bearings::Rake do
  before do
    @tmp = Dir.mktmpdir
    Rake.application = Rake::Application.new
  end

  after { FileUtils.remove_entry(@tmp) }

  def http(results)
    Struct.new(:results) { def status(url) = results.fetch(url, 200) }.new(results)
  end

  def write(path, content)
    target = File.join(@tmp, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, content)
  end

  def write_manifest(version: nil)
    write('docs-site/manifest.yml', <<~YAML)
      site:
        name: Bearings
        #{"version: #{version}" if version}
      groups:
        - label: Start here
          pages:
            - source: docs/START.md
              slug: start
            - source: docs/INSTALL.md
              slug: install
    YAML
  end

  def write_site
    write_manifest
    write('docs/START.md', "# Start\n\nSee [the example](https://a.example).\n")
    write('docs/INSTALL.md', "# Install\n")
  end

  def run_task(results = {})
    Bearings::Rake.install(http: http(results))
    status = 0
    output, = capture_io do
      Dir.chdir(@tmp) { Rake::Task['docs:check:external'].invoke }
    rescue SystemExit => e
      status = e.status
    end
    [output, status]
  end

  def output(...) = run_task(...).first

  def status(...) = run_task(...).last

  def timed_out = Bearings::Checks::ExternalLinks::Failure.new(reason: 'timed out after 10s', timed_out: true)

  describe '.install' do
    it 'reports a manifest that is not there' do
      assert_includes output, 'docs-site/manifest.yml:1: [manifest] was not found'
    end

    it 'reports the problems in a manifest that does not parse' do
      write('docs-site/manifest.yml', "site: {}\n")

      assert_includes output, 'the manifest is missing `groups`'
    end

    it 'reads the version file the manifest names' do
      write_site
      write_manifest(version: 'lib/version.rb')
      write('lib/version.rb', "VERSION = '1.0.0'\n")

      assert_empty output
    end

    it 'reports the problems from building the site' do
      write_site
      File.delete(File.join(@tmp, 'docs/INSTALL.md'))

      assert_includes output, 'docs/INSTALL.md:1: [source] is listed in the manifest but was not found'
    end

    it 'checks the guides that build when another is missing' do
      write_site
      File.delete(File.join(@tmp, 'docs/INSTALL.md'))

      assert_includes output('https://a.example' => 404),
                      'docs/START.md:3: [external-links] https://a.example returned HTTP 404'
    end

    it 'prints nothing when there are no problems' do
      write_site

      assert_empty output
    end

    it 'exits with status 1 when a problem is an error' do
      write_site

      assert_equal 1, status('https://a.example' => 404)
    end

    it 'exits with status 0 when every problem is a warning' do
      write_site

      assert_equal 0, status('https://a.example' => timed_out)
    end
  end
end
