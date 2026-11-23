# frozen_string_literal: true

require 'test_helper'
require 'bearings/rbs'

describe Bearings::Rbs do
  def declared = Bearings::Rbs.declared(File.join(__dir__, '..', 'fixtures', 'rbs'))

  describe '.declared' do
    it 'names a declared class' do
      assert_includes declared, 'Riffer::Agent'
    end

    it 'names a declared module' do
      assert_includes declared, 'Riffer::Providers'
    end

    it 'names a declared class alias' do
      assert_includes declared, 'Riffer::Model'
    end

    it 'names a declared constant' do
      assert_includes declared, 'Riffer::Agent::LIMIT'
    end

    it 'leaves out an interface' do
      refute_includes declared, 'Riffer::_Tool'
    end
  end
end
