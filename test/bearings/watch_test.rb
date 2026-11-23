# frozen_string_literal: true

require 'test_helper'

describe Bearings::Watch do
  def at(seconds) = Time.at(seconds)

  def changes(*listings, events: [], given: [])
    queue = listings.each
    listing = lambda do |before|
      events << :list
      given << before
      queue.next
    end
    Bearings::Watch.changes(listing:, wait: -> { events << :wait })
  end

  describe '.changes' do
    it 'takes the first listing when it is made' do
      events = []
      changes({}, events:)

      assert_equal [:list], events
    end

    it 'gives the first listing an empty listing before it' do
      given = []
      changes({}, given:)

      assert_equal [{}], given
    end

    it 'waits before each listing after the first' do
      events = []
      changes({ 'a.md' => at(1) }, { 'a.md' => at(2) }, { 'a.md' => at(3) }, events:).first(2)

      assert_equal %i[list wait list wait list], events
    end

    it 'gives each listing after the first the listing before it' do
      given = []
      changes({ 'a.md' => at(1) }, { 'a.md' => at(2) }, given:).first

      assert_equal [{}, { 'a.md' => at(1) }], given
    end

    it 'compares each listing with the one before it' do
      assert_equal [['a.md'], ['a.md']], changes({ 'a.md' => at(1) }, { 'a.md' => at(2) }, { 'a.md' => at(1) }).to_a
    end

    it 'yields the path whose modification time changed' do
      assert_equal [['a.md']], changes({ 'a.md' => at(1), 'b.md' => at(1) }, { 'a.md' => at(2), 'b.md' => at(1) }).to_a
    end

    it 'yields a path that appeared' do
      assert_equal [['b.md']], changes({ 'a.md' => at(1) }, { 'a.md' => at(1), 'b.md' => at(1) }).to_a
    end

    it 'yields a path that disappeared' do
      assert_equal [['b.md']], changes({ 'a.md' => at(1), 'b.md' => at(1) }, { 'a.md' => at(1) }).to_a
    end

    it 'yields a path listed as no longer there' do
      assert_equal [['a.md']], changes({ 'a.md' => at(1) }, { 'a.md' => nil }).to_a
    end

    it 'skips a path that is not there in either listing' do
      assert_empty changes({ 'a.md' => nil }, {}).to_a
    end

    it 'yields the paths that changed together in one sorted list' do
      assert_equal [['a.md', 'b.md']], changes({ 'b.md' => at(1) }, { 'a.md' => at(1), 'b.md' => at(2) }).to_a
    end

    it 'skips a listing in which nothing changed' do
      assert_equal [['a.md']], changes({ 'a.md' => at(1) }, { 'a.md' => at(1) }, { 'a.md' => at(2) }).to_a
    end
  end
end
