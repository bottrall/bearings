# frozen_string_literal: true

module Bearings::Checks::ManifestMatchesDisk
  extend self

  # @rbs manifest: Bearings::Manifest
  # @rbs paths: Array[String]
  # @rbs return: Array[Bearings::Problem]
  def call(manifest:, paths:)
    pages = manifest.groups.flat_map(&:pages)
    unlisted(paths, manifest.watch, pages.map(&:source)) + undescribed(pages)
  end

  private

  # @rbs paths: Array[String]
  # @rbs watch: Array[String]
  # @rbs sources: Array[String]
  # @rbs return: Array[Bearings::Problem]
  def unlisted(paths, watch, sources)
    folders = watch.map { |folder| "#{folder.delete_suffix('/')}/" }
    (paths - sources).select { |path| path.end_with?('.md') && path.start_with?(*folders) }.map do |path|
      Bearings::Problem.new(
        check: 'unlisted',
        level: :error,
        file: path,
        line: 1,
        message: 'is in a watched folder but no page in the manifest lists it',
        hint: 'add a page with this `source` to the manifest, or move the file out of the watched folder'
      )
    end
  end

  # @rbs pages: Array[Bearings::Manifest::Page]
  # @rbs return: Array[Bearings::Problem]
  def undescribed(pages)
    pages.select { |page| page.description.to_s.strip.empty? }.map do |page|
      Bearings::Problem.new(
        check: 'description',
        level: :error,
        file: page.source,
        line: 1,
        message: 'has no description in the manifest',
        hint: 'add a one-line `description` to its page in the manifest'
      )
    end
  end
end
