# frozen_string_literal: true

require 'cgi/escape'

module Bearings::Redirects
  extend self

  # @rbs!
  #   type issue = [String, String]

  # @rbs redirects: Array[Bearings::Manifest::Redirect]
  # @rbs url: String?
  # @rbs return: Array[Bearings::OutputFile]
  def files(redirects, url)
    redirects.map do |redirect|
      Bearings::OutputFile.new(
        path: stub_path(redirect.from),
        content: stub(redirect.to, canonical(url, redirect.to))
      )
    end
  end

  # @rbs redirects: Array[Bearings::Manifest::Redirect]
  # @rbs site: Bearings::Site
  # @rbs paths: Array[String]
  # @rbs file: String
  # @rbs return: Array[Bearings::Problem]
  def problems(redirects, site, paths:, file:)
    existing = [*site.pages.map { |page| "#{page.url}index.html" }, *paths.map { |path| "/#{path}" }]
    stubs = redirects.to_h { |redirect| ["/#{stub_path(redirect.from)}", redirect] }
    redirects.flat_map do |redirect|
      [replacing(redirect, existing), targeting(redirect, existing, stubs)].compact.map do |message, hint|
        Bearings::Problem.new(check: 'redirect', level: :error, file:, line: redirect.line, message:, hint:)
      end
    end
  end

  private

  # @rbs from: String
  # @rbs return: String
  def stub_path(from)
    [*from.split('/').reject(&:empty?), 'index.html'].join('/')
  end

  # @rbs base: String?
  # @rbs to: String
  # @rbs return: String
  def canonical(base, to)
    base ? "#{base.delete_suffix('/')}#{to}" : to
  end

  # @rbs to: String
  # @rbs canonical: String
  # @rbs return: String
  def stub(to, canonical)
    href = CGI.escapeHTML(to)
    <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Redirecting</title>
          <meta http-equiv="refresh" content="0; url=#{href}">
          <link rel="canonical" href="#{CGI.escapeHTML(canonical)}">
        </head>
        <body>
          <p>This page has moved to <a href="#{href}">#{href}</a>.</p>
        </body>
      </html>
    HTML
  end

  # @rbs redirect: Bearings::Manifest::Redirect
  # @rbs existing: Array[String]
  # @rbs return: issue?
  def replacing(redirect, existing)
    return unless existing.include?("/#{stub_path(redirect.from)}")

    [
      "redirect from `#{redirect.from}` would replace a page of the site",
      'remove the redirect; only a URL the site no longer has needs one'
    ]
  end

  # @rbs redirect: Bearings::Manifest::Redirect
  # @rbs existing: Array[String]
  # @rbs stubs: Hash[String, Bearings::Manifest::Redirect]
  # @rbs return: issue?
  def targeting(redirect, existing, stubs)
    target = redirect.to.partition('#').first
    file = target.end_with?('/') ? "#{target}index.html" : target
    chained = stubs.fetch(file, nil)
    if chained
      ["redirect from `#{redirect.from}` points to `#{redirect.to}`, another redirect", "point it at `#{chained.to}`"]
    elsif !existing.include?(file)
      [
        "redirect from `#{redirect.from}` points to `#{redirect.to}`, which is not a page or file in the site",
        'point it at a page URL such as `/guides/<slug>/`, or at a file the site writes'
      ]
    end
  end
end
