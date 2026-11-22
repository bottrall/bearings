# frozen_string_literal: true

require 'json'

module Bearings::Report
  extend self

  # @rbs problems: Array[Bearings::Problem]
  # @rbs return: String
  def text(problems)
    sorted(problems).map { |problem| text_entry(problem) }.join("\n")
  end

  # @rbs problems: Array[Bearings::Problem]
  # @rbs return: String
  def json(problems)
    JSON.generate(sorted(problems).map(&:to_h))
  end

  # @rbs problems: Array[Bearings::Problem]
  # @rbs return: bool
  def failed?(problems)
    problems.any? { |problem| problem.level == :error }
  end

  private

  # @rbs problems: Array[Bearings::Problem]
  # @rbs return: Array[Bearings::Problem]
  def sorted(problems)
    problems.sort_by { |problem| [problem.file, problem.line] }
  end

  # @rbs problem: Bearings::Problem
  # @rbs return: String
  def text_entry(problem)
    location = "#{problem.file}:#{problem.line}: [#{problem.check}] #{problem.message}"
    problem.hint ? "#{location}\n  #{problem.hint}" : location
  end
end
