# frozen_string_literal: true

module Bearings::Checks::ExternalLinks
  extend self

  EXTERNAL = %r{\Ahttps?://}i #: Regexp
  SUCCESS = 200..299 #: Range[Integer]
  HINTS = {
    error: 'fix or remove the link',
    warning: 'the site may be slow or down; run the check again later'
  }.freeze #: Hash[Symbol, String]

  # @rbs site: Bearings::Site
  # @rbs http: Bearings::_HttpClient
  # @rbs return: Array[Bearings::Problem]
  def call(site, http)
    found = site.pages.flat_map do |page|
      page.document.links.filter { |link| EXTERNAL.match?(link.href) }.map { |link| [page.source_path, link] }
    end #: Array[[String, Bearings::Document::Link]]
    results = found.map { |_, link| link.href }.uniq.to_h { |url| [url, http.status(url)] }
    found.filter_map { |file, link| problem(file, link, results.fetch(link.href)) }
  end

  private

  # @rbs file: String
  # @rbs link: Bearings::Document::Link
  # @rbs result: Integer | Bearings::Checks::ExternalLinks::Failure
  # @rbs return: Bearings::Problem?
  def problem(file, link, result)
    case result
    when SUCCESS then nil
    when Integer then failed(file, link, :error, "returned HTTP #{result}")
    else failed(file, link, result.timed_out ? :warning : :error, "could not be fetched: #{result.reason}")
    end
  end

  # @rbs file: String
  # @rbs link: Bearings::Document::Link
  # @rbs level: :error | :warning
  # @rbs outcome: String
  # @rbs return: Bearings::Problem
  def failed(file, link, level, outcome)
    Bearings::Problem.new(
      check: 'external-links',
      level:,
      file:,
      line: link.line,
      message: "#{link.href} #{outcome}",
      hint: HINTS.fetch(level)
    )
  end
end
