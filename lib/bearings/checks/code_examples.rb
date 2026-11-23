# frozen_string_literal: true

require 'json'
require 'prism'
require 'psych'

module Bearings::Checks::CodeExamples
  extend self

  # @rbs!
  #   type failure = [Integer, String]

  JSON_LOCATION = / at line (\d+) column \d+\z/ #: Regexp

  # @rbs site: Bearings::Site
  # @rbs return: Array[Bearings::Problem]
  def call(site)
    site.pages.flat_map do |page|
      page.document.code_blocks.filter_map { |block| problem(page.source_path, block) }
    end
  end

  private

  # @rbs file: String
  # @rbs block: Bearings::Document::CodeBlock
  # @rbs return: Bearings::Problem?
  def problem(file, block)
    found = failure(block.language, block.code)
    return unless found

    line, message = found
    Bearings::Problem.new(
      check: 'code',
      level: :error,
      file:,
      line: block.line + line,
      message: "the #{block.language} example does not parse: #{message}",
      hint: 'fix the example so it parses; show left-out code as a comment, not as `...`'
    )
  end

  # @rbs language: String?
  # @rbs code: String
  # @rbs return: failure?
  def failure(language, code)
    case language
    when 'ruby' then ruby(code)
    when 'json' then json(code)
    when 'yaml' then yaml(code)
    end
  end

  # @rbs code: String
  # @rbs return: failure?
  def ruby(code)
    error = Prism.parse(code).errors.first
    [error.location.start_line, error.message] if error
  end

  # @rbs code: String
  # @rbs return: failure?
  def json(code)
    JSON.parse(code)
    nil
  rescue JSON::ParserError => e
    # Older json gems, and a nesting error on any, give no line.
    [(e.message[JSON_LOCATION, 1] || 1).to_i, e.message.sub(JSON_LOCATION, '')]
  end

  # @rbs code: String
  # @rbs return: failure?
  def yaml(code)
    # Not YAML.safe_load, which also refuses valid YAML it won't build, such as an alias or a date.
    Psych.parse_stream(code)
    nil
  rescue Psych::SyntaxError => e
    [e.line.to_i, [e.problem, e.context].compact.join(' ')]
  end
end
