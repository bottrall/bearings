# frozen_string_literal: true

module Bearings::LlmsTxt
  extend self

  # @rbs site: Bearings::Site
  # @rbs copies: Array[Bearings::OutputFile]
  # @rbs full: bool
  # @rbs manifest_file: String
  # @rbs return: [Array[Bearings::OutputFile], Array[Bearings::Problem]]
  def call(site, copies, full:, manifest_file:)
    url = site.details.url
    files = [
      (Bearings::OutputFile.new(path: 'llms.txt', content: index(site, url.delete_suffix('/'))) if url),
      (Bearings::OutputFile.new(path: 'llms-full.txt', content: everything(copies)) if full)
    ].compact
    [files, url ? [] : [no_url(manifest_file)]]
  end

  private

  # @rbs manifest_file: String
  # @rbs return: Bearings::Problem
  def no_url(manifest_file)
    Bearings::Problem.new(
      check: 'llms',
      level: :warning,
      file: manifest_file,
      line: 1,
      message: 'has no `site.url`, so llms.txt was not written',
      hint: 'set `site.url` to the address the site is published at'
    )
  end

  # @rbs site: Bearings::Site
  # @rbs base: String
  # @rbs return: String
  def index(site, base)
    summary = site.details.summary
    sections = site.groups.map do |group|
      "## #{group.label}\n\n#{group.pages.map { |page| entry(page, base) }.join}"
    end
    ["# #{site.details.name}\n", *("> #{summary}\n" if summary), *sections].join("\n")
  end

  # @rbs page: Bearings::Site::Page
  # @rbs base: String
  # @rbs return: String
  def entry(page, base)
    description = ": #{page.description}" if page.description
    "- [#{page.title}](#{base}#{page.markdown_url})#{description}\n"
  end

  # @rbs copies: Array[Bearings::OutputFile]
  # @rbs return: String
  def everything(copies)
    contents = copies.map(&:content).grep(String) #: Array[String]
    # A copy keeps its guide's missing final newline, which would run its last line into the next guide's title.
    contents.map { |content| "#{content.chomp}\n" }.join("\n")
  end
end
