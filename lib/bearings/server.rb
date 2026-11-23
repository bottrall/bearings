# frozen_string_literal: true

require 'uri'

module Bearings::Server
  extend self

  METHODS = %w[GET HEAD].freeze #: Array[String]
  NOT_FOUND = '404.html' #: String
  TYPES = {
    '.css' => 'text/css; charset=utf-8',
    '.gif' => 'image/gif',
    '.html' => 'text/html; charset=utf-8',
    '.ico' => 'image/x-icon',
    '.jpeg' => 'image/jpeg',
    '.jpg' => 'image/jpeg',
    '.js' => 'text/javascript; charset=utf-8',
    '.json' => 'application/json',
    '.md' => 'text/markdown; charset=utf-8',
    '.png' => 'image/png',
    '.svg' => 'image/svg+xml',
    '.txt' => 'text/plain; charset=utf-8',
    '.webp' => 'image/webp',
    '.woff2' => 'font/woff2',
    '.xml' => 'application/xml'
  }.freeze #: Hash[String, String]

  # @rbs server: TCPServer
  # @rbs root: String
  # @rbs return: bot
  def call(server, root)
    loop { Thread.new(server.accept) { |client| answer(client, root) } }
  end

  # @rbs request: String
  # @rbs root: String
  # @rbs return: String
  def response(request, root)
    method, target = request.ascii_only? ? request.split : []
    raw = target.to_s[%r{\A/[^?#]*}]
    path = decode(raw) if raw
    return reply('400 Bad Request') unless raw && path
    return reply('405 Method Not Allowed', headers: { 'Allow' => METHODS.join(', ') }) unless METHODS.include?(method)

    file(File.expand_path(root), path, raw, head: method == 'HEAD')
  end

  private

  # @rbs client: TCPSocket
  # @rbs root: String
  # @rbs return: void
  def answer(client, root)
    request = client.gets.to_s
    # Closing with the headers unread resets the connection, which can lose the response on its way out.
    client.each_line.take_while { |line| !line.chomp.empty? }
    client.write(response(request, root))
  rescue IOError, SystemCallError
    # The browser hung up first.
  ensure
    client.close
  end

  # @rbs raw: String
  # @rbs return: String?
  def decode(raw)
    return unless raw.match?(/\A(?:[^%]|%\h\h)*\z/)

    path = URI.decode_uri_component(raw)
    path if path.valid_encoding? && !path.include?("\0")
  end

  # @rbs root: String
  # @rbs path: String
  # @rbs raw: String
  # @rbs head: bool
  # @rbs return: String
  def file(root, path, raw, head:)
    target = File.expand_path(".#{path}", root)
    return not_found(root, head:) unless target == root || target.start_with?("#{root}/")
    if File.directory?(target) && !raw.end_with?('/')
      return reply('301 Moved Permanently', headers: { 'Location' => "#{raw}/" })
    end

    page = File.directory?(target) ? File.join(target, 'index.html') : target
    File.file?(page) ? contents('200 OK', page, head:) : not_found(root, head:)
  end

  # @rbs root: String
  # @rbs head: bool
  # @rbs return: String
  def not_found(root, head:)
    page = File.join(root, NOT_FOUND)
    File.file?(page) ? contents('404 Not Found', page, head:) : reply('404 Not Found')
  end

  # @rbs status: String
  # @rbs file: String
  # @rbs head: bool
  # @rbs return: String
  def contents(status, file, head:)
    type = TYPES.fetch(File.extname(file), 'application/octet-stream')
    reply(status, headers: { 'Content-Type' => type }, body: File.binread(file), head:)
  end

  # @rbs status: String
  # @rbs headers: Hash[String, String]
  # @rbs body: String
  # @rbs head: bool
  # @rbs return: String
  def reply(status, headers: {}, body: '', head: false)
    fields = { **headers, 'Content-Length' => body.bytesize.to_s, 'Connection' => 'close' }
    ["HTTP/1.1 #{status}", *fields.map { |name, value| "#{name}: #{value}" }, '', head ? '' : body].join("\r\n")
  end
end
