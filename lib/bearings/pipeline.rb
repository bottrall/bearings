# frozen_string_literal: true

module Bearings::Pipeline
  extend self

  # @rbs!
  #   type result = [Array[Bearings::OutputFile], Array[Bearings::Problem]]
  #   type output = ^(Input) -> result
  #   type check = ^(Input, Array[Bearings::OutputFile]) -> Array[Bearings::Problem]

  Input = Data.define(
    :manifest, #: Bearings::Manifest
    :manifest_file, #: String
    :site, #: Bearings::Site
    :sources, #: Hash[String, String]
    :images, #: Hash[String, String]
    :watched, #: Array[String]
    :layout, #: String?
    :landing, #: String?
    :layout_file, #: String
    :landing_file, #: String
    :assets, #: Hash[String, Pathname]
    :declared, #: Set[String]
    :readme, #: String?
    :readme_paths #: Array[String]
  )

  OUTPUTS = [
    lambda do |input|
      layout = input.layout
      landing = input.landing
      return files_only([]) unless layout && landing

      Bearings::HtmlPages.call(input.site, layout:, landing:, assets: input.assets, images: input.images)
    end,
    ->(input) { files_only(Bearings::Images.call(input.images)) },
    ->(input) { files_only(Bearings::MarkdownCopies.call(input.site, input.sources)) },
    lambda do |input|
      copies = Bearings::MarkdownCopies.call(input.site, input.sources)
      full = input.manifest.outputs.llms_full
      Bearings::LlmsTxt.call(input.site, copies, full:, manifest_file: input.manifest_file)
    end,
    ->(input) { Bearings::Sitemap.call(input.site, manifest_file: input.manifest_file) },
    ->(input) { files_only(Bearings::Redirects.files(input.manifest.redirects, input.site.details.url)) },
    ->(input) { files_only([Bearings::SearchIndex.call(input.site)]) }
  ].freeze #: Array[output]

  CHECKS = [
    ->(input, _files) { Bearings::Checks::ManifestMatchesDisk.call(manifest: input.manifest, paths: input.watched) },
    ->(input, _files) { Bearings::Checks::CodeExamples.call(input.site) },
    ->(input, _files) { Bearings::Checks::Diagrams.call(input.site) },
    ->(input, _files) { Bearings::Checks::ConstantNames.call(site: input.site, declared: input.declared) },
    lambda do |input, _files|
      limit_kb = input.manifest.checks.image_limit_kb
      Bearings::Checks::Images.call(site: input.site, images: input.images, watched: input.watched, limit_kb:)
    end,
    lambda do |input, files|
      redirects = input.manifest.redirects
      # Redirects.problems knows the stubs; passed in as pages, each would replace itself.
      pages = files - Bearings::Redirects.files(redirects, input.site.details.url)
      Bearings::Redirects.problems(redirects, input.site, paths: pages.map(&:path), file: input.manifest_file)
    end,
    lambda do |input, files|
      Bearings::Checks::Links.call(
        input.site,
        files,
        sources: input.sources,
        markdown: Bearings::Kramdown,
        layout_file: input.layout_file,
        landing_file: input.landing_file,
        manifest_file: input.manifest_file
      )
    end,
    lambda do |input, files|
      readme = input.readme
      next [] unless readme

      Bearings::Checks::ReadmeLinks.call(
        input.site, files, readme:, paths: input.readme_paths, markdown: Bearings::Kramdown
      )
    end
  ].freeze #: Array[check]

  # @rbs input: Input
  # @rbs outputs: Array[output]
  # @rbs checks: Array[check]
  # @rbs return: result
  def call(input, outputs:, checks:)
    results = outputs.map { |output| output.call(input) }
    files = results.flat_map(&:first)
    [files, [*results.flat_map(&:last), *checks.flat_map { |check| check.call(input, files) }]]
  end

  private

  # @rbs files: Array[Bearings::OutputFile]
  # @rbs return: result
  def files_only(files)
    [files, []]
  end
end
