# frozen_string_literal: true

# Zeitwerk ignores this file, so requiring it on its own loads the gem first.
require 'bearings'
require 'pathname'
require 'rake'
require 'rouge'
require 'socket'

module Bearings::Rake
  extend self

  MANIFEST = 'docs-site/manifest.yml' #: String
  SITE = '_site' #: String
  SIG = 'sig' #: String
  LAYOUT = 'layout.html.erb' #: String
  LANDING = 'index.html.erb' #: String
  NOT_FOUND = '404.html.erb' #: String
  PARTIALS = '_*.html.erb' #: String
  HOST = '127.0.0.1' #: String
  PORT = 8000 #: Integer
  URL = "http://localhost:#{PORT}".freeze #: String
  INTERVAL = 0.5 #: Float
  FAILED = "Build failed; #{SITE}/ keeps the last good build".freeze #: String

  # @rbs!
  #   type server = ^(String root) -> void
  #   type watch = ^(Bearings::Watch::listing) -> Enumerable[Array[String]]

  SERVER = lambda do |root|
    server = TCPServer.new(HOST, PORT)
    Thread.new { Bearings::Server.call(server, root) }
  end #: server
  WATCH = ->(listing) { Bearings::Watch.changes(listing:, wait: -> { sleep(INTERVAL) }) } #: watch

  # @rbs manifest: String
  # @rbs lexers: Bearings::Kramdown::lexers
  # @rbs http: Bearings::_HttpClient
  # @rbs outputs: Array[Bearings::Pipeline::output]
  # @rbs checks: Array[Bearings::Pipeline::check]
  # @rbs server: server
  # @rbs watch: watch
  # @rbs return: void
  def install(
    manifest: MANIFEST,
    lexers: {},
    http: Bearings::NetHttp,
    outputs: Bearings::Pipeline::OUTPUTS,
    checks: Bearings::Pipeline::CHECKS,
    server: SERVER,
    watch: WATCH
  )
    language, lexer = lexers.find { |_, value| !(value.is_a?(Class) && value < ::Rouge::Lexer) }
    raise ArgumentError, "lexers: maps #{language.inspect} to #{lexer.inspect}, not a Rouge::Lexer subclass" if language

    define('docs', "Build the docs site into #{SITE}/") { build(manifest, outputs, [], lexers) }
    define('docs:check', 'Build the docs site and check it, failing on any error') do
      build(manifest, outputs, checks, lexers)
    end
    task('docs:serve', "Build the docs site, serve it at #{URL} and rebuild it when its files change") do
      serve(manifest, outputs, server, watch, lexers)
    end
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
    task(name, description) { finish(yield, ENV.fetch('FORMAT', nil)) }
  end

  # @rbs name: String
  # @rbs description: String
  # @rbs &action: () -> void
  # @rbs return: void
  def task(name, description, &)
    ::Rake.application.last_description = description
    ::Rake::Task.define_task(name, &)
  end

  # @rbs path: String
  # @rbs outputs: Array[Bearings::Pipeline::output]
  # @rbs checks: Array[Bearings::Pipeline::check]
  # @rbs lexers: Bearings::Kramdown::lexers
  # @rbs return: Array[Bearings::Problem]
  def build(path, outputs, checks, lexers)
    files, problems = render(path, outputs, checks, lexers)
    files ? [*problems, *Bearings::Writer.call(files, SITE)] : problems
  end

  # @rbs path: String
  # @rbs outputs: Array[Bearings::Pipeline::output]
  # @rbs server: server
  # @rbs watch: watch
  # @rbs lexers: Bearings::Kramdown::lexers
  # @rbs return: void
  def serve(path, outputs, server, watch, lexers)
    # Each rebuild's report has to show as it happens, even when stdout is a pipe that would buffer it.
    $stdout.sync = true
    # Listed before the first build, so an edit saved while it runs still counts as a change.
    changes = watch.call(->(before) { listing(path, before) })
    rebuild(path, outputs, lexers)
    server.call(SITE)
    puts "Serving #{SITE}/ at #{URL}; press Ctrl-C to stop"
    changes.each do |changed|
      puts "#{changed.join(', ')} changed; rebuilding"
      rebuild(path, outputs, lexers)
    end
  rescue Interrupt
    puts "Stopped serving #{SITE}/"
  end

  # @rbs path: String
  # @rbs outputs: Array[Bearings::Pipeline::output]
  # @rbs lexers: Bearings::Kramdown::lexers
  # @rbs return: void
  def rebuild(path, outputs, lexers)
    files, found = render(path, outputs, [], lexers)
    problems = files && !Bearings::Report.failed?(found) ? [*found, *Bearings::Writer.call(files, SITE)] : found
    puts Bearings::Report.text(problems) if problems.any?
    puts Bearings::Report.failed?(problems) ? FAILED : "Built #{SITE}/"
  # The templates are the repo's ERB, run as Ruby: a typo saved in one raises, as a SyntaxError (a ScriptError) for
  # some, and the server has to outlive it.
  rescue StandardError, ScriptError => e
    puts "#{e.class}: #{e.message}", FAILED
  end

  # @rbs path: String
  # @rbs outputs: Array[Bearings::Pipeline::output]
  # @rbs checks: Array[Bearings::Pipeline::check]
  # @rbs lexers: Bearings::Kramdown::lexers
  # @rbs return: [Array[Bearings::OutputFile]?, Array[Bearings::Problem]]
  def render(path, outputs, checks, lexers)
    input, problems = input(path, lexers)
    return [nil, problems] unless input

    files, found = Bearings::Pipeline.call(input, outputs:, checks:)
    [files, [*problems, *found]]
  end

  # @rbs path: String
  # @rbs before: Hash[String, Time?]
  # @rbs return: Hash[String, Time?]
  def listing(path, before)
    manifest, = manifest(path)
    named = manifest ? [*source_paths(manifest), *watched(manifest.watch)] : [] #: Array[String]
    listed = [*named, *assets(File.dirname(path), []).values.map(&:to_s)]
    # The last listing's paths carry the images the guides use, which only a render finds, and while the manifest does
    # not parse they stand in for the paths it names; without them each would read as changed.
    known = mtimes([*before.keys, *listed])
    # Finding the images the guides use renders every guide, so it waits for a change to a listed file, the only
    # thing that can change them.
    return known if !manifest || known == before

    site, = Bearings::Site.build(manifest:, files: sources(manifest), markdown: Bearings::Kramdown)
    mtimes([*listed, *Bearings::Images.paths(site)])
  # A guide that fails to render still reads as changed, so the rebuild runs and prints why; a file deleted between
  # its stat calls falls back to the paths already stat'd.
  rescue StandardError
    known || before
  end

  # @rbs paths: Array[String]
  # @rbs return: Hash[String, Time?]
  def mtimes(paths)
    files = paths.map { |file| Pathname(file).cleanpath.to_s }.uniq
    files.to_h { |file| [file, (File.mtime(file) if File.file?(file))] }
  end

  # @rbs path: String
  # @rbs http: Bearings::_HttpClient
  # @rbs return: Array[Bearings::Problem]
  def external(path, http)
    manifest, problems = manifest(path)
    return problems unless manifest

    site, built = Bearings::Site.build(manifest:, files: sources(manifest), markdown: Bearings::Kramdown)
    [*built, *Bearings::Checks::ExternalLinks.call(site, http)]
  end

  # @rbs path: String
  # @rbs lexers: Bearings::Kramdown::lexers
  # @rbs return: [Bearings::Pipeline::Input?, Array[Bearings::Problem]]
  def input(path, lexers)
    manifest, problems = manifest(path)
    return [nil, problems] unless manifest

    sources = sources(manifest)
    site, built = Bearings::Site.build(manifest:, files: sources, markdown: Bearings::Kramdown::WithLexers.new(lexers:))
    dir = File.dirname(path)
    layout_file = File.join(dir, LAYOUT)
    landing_file = File.join(dir, LANDING)
    not_found_file = File.join(dir, NOT_FOUND)
    required = [layout_file, landing_file]
    layout, landing, not_found = [*required, not_found_file].map do |template|
      File.read(template) if File.file?(template)
    end
    partials = partials(dir)
    readme = read_readme
    input = Bearings::Pipeline::Input.new(
      manifest:,
      manifest_file: path,
      site:,
      sources:,
      images: images(site),
      watched: watched(manifest.watch),
      layout:,
      landing:,
      not_found:,
      layout_file:,
      landing_file:,
      not_found_file:,
      partials:,
      assets: assets(dir, [File.basename(path), LAYOUT, LANDING, NOT_FOUND, *partials.keys]),
      declared: declared(manifest.site.namespaces),
      readme:,
      readme_paths: readme_paths(readme)
    )
    [input, [*built, *required.reject { |template| File.file?(template) }.map { |template| no_template(template) }]]
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
    source_paths(manifest).select { |path| File.file?(path) }.to_h { |path| [path, File.read(path)] }
  end

  # @rbs manifest: Bearings::Manifest
  # @rbs return: Array[String]
  def source_paths(manifest)
    [*manifest.groups.flat_map(&:pages).map(&:source), manifest.site.version].compact
  end

  # @rbs site: Bearings::Site
  # @rbs return: Hash[String, String]
  def images(site)
    Bearings::Images.paths(site).select { |path| File.file?(path) }.to_h { |path| [path, File.binread(path)] }
  end

  # @rbs folders: Array[String]
  # @rbs return: Array[String]
  def watched(folders)
    Dir.glob(folders.map { |folder| File.join(folder, '**', '*') }).select { |path| File.file?(path) }
  end

  # @rbs dir: String
  # @rbs return: Hash[String, String]
  def partials(dir)
    Dir.glob(PARTIALS, base: dir).to_h { |partial| [partial, File.read(File.join(dir, partial))] }
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

  # @rbs return: String?
  def read_readme
    file = Bearings::Checks::ReadmeLinks::FILE
    File.read(file) if File.file?(file)
  end

  # @rbs readme: String?
  # @rbs return: Array[String]
  def readme_paths(readme)
    return [] unless readme

    Bearings::Checks::ReadmeLinks.paths(readme, markdown: Bearings::Kramdown).select { |path| File.exist?(path) }
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
