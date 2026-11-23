# frozen_string_literal: true

# Zeitwerk ignores this file, so requiring it on its own loads the gem first.
require 'bearings'
require 'pathname'
require 'rake'

module Bearings::Rake
  extend self

  MANIFEST = 'docs-site/manifest.yml' #: String
  SITE = '_site' #: String
  SIG = 'sig' #: String
  LAYOUT = 'layout.html.erb' #: String
  LANDING = 'index.html.erb' #: String

  # @rbs manifest: String
  # @rbs http: Bearings::_HttpClient
  # @rbs outputs: Array[Bearings::Pipeline::output]
  # @rbs checks: Array[Bearings::Pipeline::check]
  # @rbs return: void
  def install(
    manifest: MANIFEST,
    http: Bearings::NetHttp,
    outputs: Bearings::Pipeline::OUTPUTS,
    checks: Bearings::Pipeline::CHECKS
  )
    define('docs', "Build the docs site into #{SITE}/") { build(manifest, outputs, []) }
    define('docs:check', 'Build the docs site and check it, failing on any error') { build(manifest, outputs, checks) }
    define('docs:check:external', 'Request every external link in the guides and report the ones that fail') do
      external(manifest, http)
    end
  end

  private

  # @rbs name: String
  # @rbs description: String
  # @rbs &problems: () -> Array[Bearings::Problem]
  # @rbs return: void
  def define(name, description, &)
    ::Rake.application.last_description = description
    ::Rake::Task.define_task(name) { finish(yield, ENV.fetch('FORMAT', nil)) }
  end

  # @rbs path: String
  # @rbs outputs: Array[Bearings::Pipeline::output]
  # @rbs checks: Array[Bearings::Pipeline::check]
  # @rbs return: Array[Bearings::Problem]
  def build(path, outputs, checks)
    input, problems = input(path)
    return problems unless input

    files, found = Bearings::Pipeline.call(input, outputs:, checks:)
    [*problems, *found, *Bearings::Writer.call(files, SITE)]
  end

  # @rbs path: String
  # @rbs http: Bearings::_HttpClient
  # @rbs return: Array[Bearings::Problem]
  def external(path, http)
    manifest, problems = manifest(path)
    return problems unless manifest

    site, built = site(manifest, sources(manifest))
    [*built, *Bearings::Checks::ExternalLinks.call(site, http)]
  end

  # @rbs path: String
  # @rbs return: [Bearings::Pipeline::Input?, Array[Bearings::Problem]]
  def input(path)
    manifest, problems = manifest(path)
    return [nil, problems] unless manifest

    sources = sources(manifest)
    site, built = site(manifest, sources)
    dir = File.dirname(path)
    templates = [LAYOUT, LANDING].map { |name| File.join(dir, name) }
    layout, landing = templates.map { |template| File.read(template) if File.file?(template) }
    input = Bearings::Pipeline::Input.new(
      manifest:,
      manifest_file: path,
      site:,
      sources:,
      images: images(site),
      watched: watched(manifest.watch),
      layout:,
      landing:,
      assets: assets(dir, [File.basename(path), LAYOUT, LANDING]),
      declared: declared(manifest.site.namespaces)
    )
    [input, [*built, *templates.reject { |template| File.file?(template) }.map { |template| no_template(template) }]]
  end

  # @rbs path: String
  # @rbs return: [Bearings::Manifest?, Array[Bearings::Problem]]
  def manifest(path)
    return [nil, [no_manifest(path)]] unless File.file?(path)

    manifest = Bearings::Manifest::Parser.parse(File.read(path), file: path)
    manifest.is_a?(Array) ? [nil, manifest] : [manifest, []]
  end

  # @rbs manifest: Bearings::Manifest
  # @rbs return: Hash[String, String]
  def sources(manifest)
    paths = [*manifest.groups.flat_map(&:pages).map(&:source), manifest.site.version].compact
    paths.select { |path| File.file?(path) }.to_h { |path| [path, File.read(path)] }
  end

  # @rbs site: Bearings::Site
  # @rbs return: Hash[String, String]
  def images(site)
    Bearings::Images.paths(site).select { |path| File.file?(path) }.to_h { |path| [path, File.binread(path)] }
  end

  # @rbs manifest: Bearings::Manifest
  # @rbs sources: Hash[String, String]
  # @rbs return: [Bearings::Site, Array[Bearings::Problem]]
  def site(manifest, sources)
    Bearings::Site.build(manifest:, files: sources, markdown: Bearings::Kramdown)
  end

  # @rbs folders: Array[String]
  # @rbs return: Array[String]
  def watched(folders)
    Dir.glob(folders.map { |folder| File.join(folder, '**', '*') }).select { |path| File.file?(path) }
  end

  # @rbs dir: String
  # @rbs read: Array[String]
  # @rbs return: Hash[String, Pathname]
  def assets(dir, read)
    # A manifest at the repo root would otherwise copy the last build into the next one.
    site = "#{File.expand_path(SITE)}/"
    files = (Dir.glob('**/*', base: dir) - read).map { |path| File.join(dir, path) }.select do |file|
      File.file?(file) && !File.expand_path(file).start_with?(site)
    end
    files.to_h { |file| [file.delete_prefix("#{dir}/"), Pathname(file)] }
  end

  # @rbs namespaces: Array[String]
  # @rbs return: Set[String]
  def declared(namespaces)
    # Only a site that names its namespaces checks constants, so only it needs the rbs gem, and bearings/rbs is
    # required here, by name, because Zeitwerk ignores it.
    return Set.new if namespaces.empty?

    require 'bearings/rbs'
    Bearings::Rbs.declared(SIG)
  end

  # @rbs path: String
  # @rbs return: Bearings::Problem
  def no_manifest(path)
    not_found(path, 'manifest', 'add the manifest, or pass its path to Bearings::Rake.install(manifest:)')
  end

  # @rbs path: String
  # @rbs return: Bearings::Problem
  def no_template(path)
    not_found(
      path,
      'layout',
      "add it beside the manifest; #{LAYOUT} renders each guide and #{LANDING} the landing page"
    )
  end

  # @rbs path: String
  # @rbs check: String
  # @rbs hint: String
  # @rbs return: Bearings::Problem
  def not_found(path, check, hint)
    Bearings::Problem.new(check:, level: :error, file: path, line: 1, message: 'was not found', hint:)
  end

  # @rbs problems: Array[Bearings::Problem]
  # @rbs format: String?
  # @rbs return: void
  def finish(problems, format)
    if format == 'json'
      puts Bearings::Report.json(problems)
    elsif problems.any?
      puts Bearings::Report.text(problems)
    end
    exit 1 if Bearings::Report.failed?(problems)
  end
end
