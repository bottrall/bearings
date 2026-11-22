# frozen_string_literal: true

require 'test_helper'

describe Bearings::Report do
  def problem(**fields)
    Bearings::Problem.new(
      check: 'links',
      level: :error,
      file: 'guides/start.md',
      line: 3,
      message: 'links to a missing guide',
      hint: 'check the path',
      **fields
    )
  end

  def unsorted
    [
      problem(file: 'guides/b.md', line: 1, hint: nil),
      problem(file: 'guides/a.md', line: 10, hint: nil),
      problem(file: 'guides/a.md', line: 2, hint: nil)
    ]
  end

  describe '.text' do
    it 'sorts problems by file, then line' do
      assert_equal(
        %w[guides/a.md:2: guides/a.md:10: guides/b.md:1:],
        Bearings::Report.text(unsorted).lines.map { |line| line.split.first }
      )
    end

    it 'prints a problem as file:line: [check] message, with its hint on the next line' do
      assert_equal "guides/start.md:3: [links] links to a missing guide\n  check the path",
                   Bearings::Report.text([problem])
    end

    it 'leaves out the hint line when a problem has no hint' do
      assert_equal 'guides/start.md:3: [links] links to a missing guide', Bearings::Report.text([problem(hint: nil)])
    end
  end

  describe '.json' do
    it 'sorts problems by file, then line' do
      assert_equal(
        [['guides/a.md', 2], ['guides/a.md', 10], ['guides/b.md', 1]],
        JSON.parse(Bearings::Report.json(unsorted)).map { |entry| entry.values_at('file', 'line') }
      )
    end

    it 'prints an array of objects with the six fields' do
      assert_equal [{ 'check' => 'links', 'level' => 'error', 'file' => 'guides/start.md', 'line' => 3,
                      'message' => 'links to a missing guide', 'hint' => 'check the path' }],
                   JSON.parse(Bearings::Report.json([problem]))
    end

    it 'gives null for a missing hint' do
      assert_nil JSON.parse(Bearings::Report.json([problem(hint: nil)])).first.fetch('hint')
    end
  end

  describe '.failed?' do
    it 'fails a list holding an error' do
      assert Bearings::Report.failed?([problem(level: :warning), problem(level: :error)])
    end

    it 'passes a list holding only warnings' do
      refute Bearings::Report.failed?([problem(level: :warning)])
    end

    it 'passes an empty list' do
      refute Bearings::Report.failed?([])
    end
  end
end
