# frozen_string_literal: true

require 'cgi/escape'
require 'json'

module Bearings::SearchIndex
  extend self

  Entry = Data.define(
    :title, #: String
    :heading, #: String?
    :text, #: String
    :url #: String
  )

  PATH = 'search.json' #: String
  URL = "/#{PATH}".freeze #: String
  HEADING = %r{<h[1-6] id="([^"]*)">(.*?)</h[1-6]>}m #: Regexp
  TAG = /<[^>]*>/ #: Regexp
  SPACE = /[[:space:]]+/ #: Regexp

  # @rbs site: Bearings::Site
  # @rbs return: Bearings::OutputFile
  def call(site)
    index = site.pages.flat_map { |page| entries(page) }.map(&:to_h)
    Bearings::OutputFile.new(path: PATH, content: JSON.generate(index))
  end

  private

  # @rbs page: Bearings::Site::Page
  # @rbs return: Array[Entry]
  def entries(page)
    intro, *sections = page.document.body.split(HEADING)
    lead = plain(intro.to_s)
    headed = sections.each_slice(3).map do |id, heading, html|
      Entry.new(title: page.title, heading: plain(heading.to_s), text: plain(html.to_s), url: "#{page.url}##{id}")
    end
    lead.empty? ? headed : [Entry.new(title: page.title, heading: nil, text: lead, url: page.url), *headed]
  end

  # @rbs html: String
  # @rbs return: String
  def plain(html)
    CGI.unescapeHTML(html.gsub(TAG, '')).gsub(SPACE, ' ').strip
  end
end
