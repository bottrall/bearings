# frozen_string_literal: true

module Bearings::Watch
  extend self

  # @rbs!
  #   type listing = ^(Hash[String, Time?] before) -> Hash[String, Time?]
  #   type pair = [Hash[String, Time?], Hash[String, Time?]]

  # @rbs listing: listing
  # @rbs wait: ^() -> void
  # @rbs return: Enumerable[Array[String]]
  def changes(listing:, wait:)
    first = listing.call({})
    unchanged = [first, first] #: pair
    pairs = Enumerator.produce(unchanged) do |pair|
      wait.call
      [pair.last, listing.call(pair.last)]
    end
    pairs.lazy.map { |before, after| changed(before, after) }.reject(&:empty?)
  end

  private

  # @rbs before: Hash[String, Time?]
  # @rbs after: Hash[String, Time?]
  # @rbs return: Array[String]
  def changed(before, after)
    (before.keys | after.keys).reject { |path| before[path] == after[path] }.sort
  end
end
