# frozen_string_literal: true

require 'pathname'

module Bearings::Images
  extend self

  SOURCE_URL = /(?:\A|,)\s*\K[^\s,]+/ #: Regexp
  TAG = /<(?<name>img|source)\s[^>]*>/ #: Regexp
  ATTRIBUTE = /(?<=\s)(?<name>[^\s=]+)="(?<value>[^"]*)"/ #: Regexp
  SOURCE_ATTRIBUTES = %w[src srcset].freeze #: Array[String]
  TAG_END = %r{\s*/?>\z} #: Regexp

  # @rbs path: String
  # @rbs return: String
  def url(path)
    "/assets/#{path}"
  end

  # @rbs site: Bearings::Site
  # @rbs return: Array[String]
  def paths(site)
    site.pages.flat_map do |page|
      page.document.images.filter_map { |image| Bearings::RepoPath.resolve(page.source_path, image.src) }
    end.uniq
  end

  # @rbs site: Bearings::Site
  # @rbs images: Hash[String, String]
  # @rbs return: Array[Bearings::OutputFile]
  def call(site, images)
    paths(site).select { |path| images.key?(path) }.map do |path|
      Bearings::OutputFile.new(path: url(path).delete_prefix('/'), content: Pathname(path))
    end
  end

  # @rbs body: String
  # @rbs from: String
  # @rbs images: Hash[String, String]
  # @rbs return: String
  def html(body, from, images)
    body.gsub(TAG) do |tag|
      match = Regexp.last_match #: MatchData
      attributes = tag.scan(ATTRIBUTE).to_h #: Hash[String, String]
      src = attributes['src'] if match[:name] == 'img'
      path = Bearings::RepoPath.resolve(from, src) if src
      rewritten = sources(tag, from)
      path ? sized(rewritten, attributes, images[path]) : rewritten
    end
  end

  private

  # @rbs tag: String
  # @rbs from: String
  # @rbs return: String
  def sources(tag, from)
    tag.gsub(ATTRIBUTE) do |attribute|
      match = Regexp.last_match #: MatchData
      name = match[:name].to_s
      next attribute unless SOURCE_ATTRIBUTES.include?(name)

      urls = match[:value].to_s.gsub(SOURCE_URL) do |source|
        Bearings::RepoPath.resolve(from, source)&.then { |path| url(path) } || source
      end
      %(#{name}="#{urls}")
    end
  end

  # @rbs tag: String
  # @rbs attributes: Hash[String, String]
  # @rbs bytes: String?
  # @rbs return: String
  def sized(tag, attributes, bytes)
    given = attributes.key?('width') || attributes.key?('height')
    width, height = Bearings::Images::Dimensions.call(bytes) if bytes && !given
    added = [
      *(%( width="#{width}" height="#{height}") if width && height),
      *(' loading="lazy"' unless attributes.key?('loading'))
    ]
    tag.sub(TAG_END) { |tag_end| "#{added.join}#{tag_end}" }
  end
end
