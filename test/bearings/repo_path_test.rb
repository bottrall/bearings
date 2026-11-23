# frozen_string_literal: true

require 'test_helper'

describe Bearings::RepoPath do
  describe '.resolve' do
    {
      'an external URL' => 'https://example.com/INSTALL.md',
      'a mailto link' => 'mailto:team@example.com',
      'a root-relative path' => '/images/logo.png'
    }.each do |kind, destination|
      it "gives nil for #{kind}" do
        assert_nil Bearings::RepoPath.resolve('docs/START.md', destination)
      end
    end

    it "resolves a path from the file's folder" do
      assert_equal 'docs/images/logo.png', Bearings::RepoPath.resolve('docs/START.md', 'images/logo.png')
    end

    it 'resolves a path that starts with ./' do
      assert_equal 'docs/INSTALL.md', Bearings::RepoPath.resolve('docs/START.md', './INSTALL.md')
    end

    it 'resolves a path that climbs out of the folder with ../' do
      assert_equal 'docs/START.md', Bearings::RepoPath.resolve('docs/reference/MANIFEST.md', '../START.md')
    end

    it 'gives nil for a path that climbs out of the repo' do
      assert_nil Bearings::RepoPath.resolve('docs/START.md', '../../secrets/key.png')
    end
  end
end
