# frozen_string_literal: true

require 'test_helper'

describe Bearings::Greeting do
  describe '.call' do
    it 'greets the world when given no name' do
      assert_equal 'Hello, world!', Bearings::Greeting.call
    end

    it 'greets the name it is given' do
      assert_equal 'Hello, Ada!', Bearings::Greeting.call('Ada')
    end
  end
end
