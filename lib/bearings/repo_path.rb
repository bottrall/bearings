# frozen_string_literal: true

require 'pathname'

module Bearings::RepoPath
  extend self

  SCHEME = /\A[a-z][a-z\d+.-]*:/i #: Regexp

  # @rbs from: String
  # @rbs destination: String
  # @rbs return: String?
  def resolve(from, destination)
    return if destination.match?(SCHEME) || destination.start_with?('/')

    path = Pathname.new(File.join(File.dirname(from), destination)).cleanpath.to_s
    path unless path == '..' || path.start_with?('../')
  end
end
