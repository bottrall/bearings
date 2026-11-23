# frozen_string_literal: true

module Bearings::Images::Dimensions
  extend self

  PNG = "\x89PNG\r\n\x1A\n".b #: String
  GIF = %w[GIF87a GIF89a].freeze #: Array[String]
  JPEG = "\xFF\xD8".b #: String
  # The start-of-frame markers, which hold the size; C4, C8 and CC fall in their range but mark other segments.
  JPEG_FRAMES = ((0xC0..0xCF).to_a - [0xC4, 0xC8, 0xCC]).freeze #: Array[Integer]
  SVG = /<svg\b[^>]*>/ #: Regexp
  SVG_LENGTH = '\s*=\s*["\']\s*(\d+(?:\.\d+)?)(?:px)?\s*["\']' #: String
  SVG_WIDTH = /\swidth#{SVG_LENGTH}/ #: Regexp
  SVG_HEIGHT = /\sheight#{SVG_LENGTH}/ #: Regexp
  SVG_VIEW_BOX = /\sviewBox\s*=\s*["']\s*[-\d.]+[\s,]+[-\d.]+[\s,]+(\d+(?:\.\d+)?)[\s,]+(\d+(?:\.\d+)?)\s*["']/ #: Regexp

  # @rbs bytes: String
  # @rbs return: [Integer, Integer]?
  def call(bytes)
    data = bytes.b
    return png(data) if data.start_with?(PNG)
    return gif(data) if data.start_with?(*GIF)
    return jpeg(data, JPEG.bytesize) if data.start_with?(JPEG)

    svg(data)
  end

  private

  # @rbs data: String
  # @rbs return: [Integer, Integer]?
  def png(data)
    pair(data, 'N2', 16) if data.bytesize >= 24
  end

  # @rbs data: String
  # @rbs return: [Integer, Integer]?
  def gif(data)
    pair(data, 'v2', 6) if data.bytesize >= 10
  end

  # @rbs data: String
  # @rbs at: Integer
  # @rbs return: [Integer, Integer]?
  def jpeg(data, at)
    return if data.bytesize < at + 9

    prefix, marker, length = data.unpack('C2n', offset: at) #: [Integer, Integer, Integer]
    return unless prefix == 0xFF
    return jpeg(data, at + 2 + length) unless JPEG_FRAMES.include?(marker)

    height, width = pair(data, 'n2', at + 5)
    [width, height]
  end

  # @rbs data: String
  # @rbs format: String
  # @rbs offset: Integer
  # @rbs return: [Integer, Integer]
  def pair(data, format, offset)
    data.unpack(format, offset:) #: [Integer, Integer]
  end

  # @rbs data: String
  # @rbs return: [Integer, Integer]?
  def svg(data)
    tag = data[SVG].to_s
    width = tag[SVG_WIDTH, 1]
    height = tag[SVG_HEIGHT, 1]
    return pixels(width, height) if width && height

    view_box = tag.match(SVG_VIEW_BOX)
    pixels(view_box[1].to_s, view_box[2].to_s) if view_box
  end

  # @rbs width: String
  # @rbs height: String
  # @rbs return: [Integer, Integer]
  def pixels(width, height)
    [Float(width).round, Float(height).round]
  end
end
