# frozen_string_literal: true

module Bearings::Rake
  extend self

  MANIFEST = 'docs-site/manifest.yml' #: String

  # @rbs manifest: String
  # @rbs http: Bearings::_HttpClient
  # @rbs return: void
  def install(manifest: MANIFEST, http: Bearings::NetHttp)
    ::Rake.application.last_description = 'Request every external link in the guides and report the ones that fail'
    ::Rake::Task.define_task('docs:check:external') { finish(external(manifest, http)) }
  end

  private

  # @rbs manifest: String
  # @rbs http: Bearings::_HttpClient
  # @rbs return: Array[Bearings::Problem]
  def external(manifest, http)
    site, problems = site(manifest)
    site ? [*problems, *Bearings::Checks::ExternalLinks.call(site, http)] : problems
  end

  # @rbs path: String
  # @rbs return: [Bearings::Site?, Array[Bearings::Problem]]
  def site(path)
    return [nil, [missing(path)]] unless File.file?(path)

    manifest = Bearings::Manifest::Parser.parse(File.read(path), file: path)
    return [nil, manifest] if manifest.is_a?(Array)

    Bearings::Site.build(manifest:, files: files(manifest), markdown: Bearings::Kramdown)
  end

  # @rbs path: String
  # @rbs return: Bearings::Problem
  def missing(path)
    Bearings::Problem.new(
      check: 'manifest',
      level: :error,
      file: path,
      line: 1,
      message: 'was not found',
      hint: 'add the manifest, or pass its path to Bearings::Rake.install(manifest:)'
    )
  end

  # @rbs manifest: Bearings::Manifest
  # @rbs return: Hash[String, String]
  def files(manifest)
    paths = [*manifest.groups.flat_map(&:pages).map(&:source), manifest.site.version].compact
    paths.select { |path| File.file?(path) }.to_h { |path| [path, File.read(path)] }
  end

  # @rbs problems: Array[Bearings::Problem]
  # @rbs return: void
  def finish(problems)
    puts Bearings::Report.text(problems) unless problems.empty?
    exit 1 if Bearings::Report.failed?(problems)
  end
end
