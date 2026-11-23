# frozen_string_literal: true

require 'test_helper'

describe Bearings::Images::Dimensions do
  def png(header) = "\x89PNG\r\n\x1A\n".b + header

  def jpeg(*segments) = "\xFF\xD8".b + segments.join

  def segment(marker, body) = [0xFF, marker, body.bytesize + 2].pack('C2n') + body

  def frame(marker = 0xC0) = segment(marker, [8, 480, 640, 1].pack('Cn2C') + ("\x00" * 3))

  def size(bytes) = Bearings::Images::Dimensions.call(bytes)

  describe '.call' do
    it "reads a PNG's width and height from its header" do
      assert_equal [640, 480], size(png([13, 'IHDR', 640, 480].pack('Na4N2')))
    end

    it 'gives nil for a PNG cut off before its size' do
      assert_nil size(png([13].pack('N')))
    end

    it "reads a GIF's width and height from its header" do
      assert_equal [640, 480], size("GIF89a#{[640, 480].pack('v2')}")
    end

    it 'gives nil for a GIF cut off before its size' do
      assert_nil size('GIF87a')
    end

    it "reads a JPEG's width and height from its frame header" do
      assert_equal [640, 480], size(jpeg(frame))
    end

    it 'reads the frame header of a progressive JPEG' do
      assert_equal [640, 480], size(jpeg(frame(0xC2)))
    end

    it 'skips the segments before the frame header' do
      assert_equal [640, 480], size(jpeg(segment(0xE0, "JFIF\x00"), frame))
    end

    it 'skips a Huffman table, whose marker falls among the frame markers' do
      assert_equal [640, 480], size(jpeg(segment(0xC4, "\x00" * 20), frame))
    end

    it 'gives nil for a JPEG with no frame header' do
      assert_nil size(jpeg(segment(0xE0, "JFIF\x00")))
    end

    it 'gives nil for a JPEG whose next segment has no marker' do
      assert_nil size(jpeg("\x00" * 12))
    end

    it "reads an SVG's width and height" do
      assert_equal [120, 80], size('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="80">')
    end

    it 'reads an SVG width and height in px, rounded' do
      assert_equal [121, 80], size(%(<?xml version="1.0"?>\n<svg width='120.5px' height="80px"></svg>))
    end

    it 'reads the size from the viewBox of an SVG with no width and height' do
      assert_equal [300, 150], size('<svg viewBox="0 0 300 150">')
    end

    it 'reads the size from the viewBox of an SVG whose width and height are not in pixels' do
      assert_equal [300, 150], size('<svg width="100%" height="100%" viewBox="-10,-10,300,150">')
    end

    it 'gives nil for an SVG with no size' do
      assert_nil size('<svg xmlns="http://www.w3.org/2000/svg">')
    end

    it 'gives nil for a file that is not an image' do
      assert_nil size('plain text')
    end
  end
end
