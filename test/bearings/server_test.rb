# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'net/http'
require 'socket'
require 'tmpdir'

describe Bearings::Server do
  before do
    @tmp = Dir.mktmpdir
    @root = File.join(@tmp, '_site')
    write('index.html', 'home')
    write('guides/start/index.html', 'start')
    File.write(File.join(@tmp, 'secret.txt'), 'secret')
  end

  after { FileUtils.remove_entry(@tmp) }

  def write(path, content, root: @root)
    target = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, content)
  end

  def respond(request) = Bearings::Server.response(request, @root)

  def status(request) = respond(request).lines.first.chomp

  def body(request) = respond(request).split("\r\n\r\n", 2).last

  def header(request, name)
    respond(request).split("\r\n\r\n", 2).first.lines.drop(1).map(&:chomp).to_h { |line| line.split(': ', 2) }[name]
  end

  describe '.call' do
    it 'answers each connection the server accepts' do
      server = TCPServer.new('127.0.0.1', 0)
      thread = Thread.new { Bearings::Server.call(server, @root) }

      assert_equal 'start', Net::HTTP.get(URI("http://127.0.0.1:#{server.addr[1]}/guides/start/"))
    ensure
      thread&.kill
      server&.close
    end

    it 'keeps answering after a browser hangs up before it asks' do
      server = TCPServer.new('127.0.0.1', 0)
      thread = Thread.new { Bearings::Server.call(server, @root) }
      browser = TCPSocket.new('127.0.0.1', server.addr[1])
      # Lingering for no time makes closing reset the connection, so the server's read fails rather than ends.
      browser.setsockopt(Socket::Option.linger(true, 0))
      browser.close

      assert_equal 'start', Net::HTTP.get(URI("http://127.0.0.1:#{server.addr[1]}/guides/start/"))
    ensure
      thread&.kill
      server&.close
    end
  end

  describe '.response' do
    it 'rejects a request line that is not ASCII' do
      assert_equal 'HTTP/1.1 400 Bad Request', status("GET /\xFF HTTP/1.1")
    end

    it 'rejects an empty request' do
      assert_equal 'HTTP/1.1 400 Bad Request', status('')
    end

    it 'rejects a target that is not a path' do
      assert_equal 'HTTP/1.1 400 Bad Request', status('GET http://localhost/ HTTP/1.1')
    end

    it 'rejects a path with a broken percent-encoding' do
      assert_equal 'HTTP/1.1 400 Bad Request', status('GET /%zz HTTP/1.1')
    end

    it 'rejects a path that decodes to invalid UTF-8' do
      assert_equal 'HTTP/1.1 400 Bad Request', status('GET /%FF HTTP/1.1')
    end

    it 'rejects a path that decodes to a null byte' do
      assert_equal 'HTTP/1.1 400 Bad Request', status('GET /index.html%00 HTTP/1.1')
    end

    it 'ignores the query' do
      assert_equal 'start', body('GET /guides/start/?q=1 HTTP/1.1')
    end

    it 'decodes a percent-encoded path' do
      write('my notes.txt', 'notes')

      assert_equal 'notes', body('GET /my%20notes.txt HTTP/1.1')
    end

    it 'refuses a method other than GET and HEAD' do
      assert_equal 'HTTP/1.1 405 Method Not Allowed', status('POST / HTTP/1.1')
    end

    it 'names the methods it allows when it refuses one' do
      assert_equal 'GET, HEAD', header('POST / HTTP/1.1', 'Allow')
    end

    it 'does not serve a file above the root' do
      assert_equal 'HTTP/1.1 404 Not Found', status('GET /../secret.txt HTTP/1.1')
    end

    it 'does not serve a file above the root through a percent-encoded path' do
      assert_equal 'HTTP/1.1 404 Not Found', status('GET /%2e%2e/secret.txt HTTP/1.1')
    end

    it 'does not serve a file in a sibling folder whose name starts with the root' do
      write('secret.txt', 'secret', root: "#{@root}-other")

      assert_equal 'HTTP/1.1 404 Not Found', status('GET /../_site-other/secret.txt HTTP/1.1')
    end

    it 'redirects a folder without a trailing slash to the path with one' do
      assert_equal 'HTTP/1.1 301 Moved Permanently', status('GET /guides/start HTTP/1.1')
    end

    it 'points the redirect at the path with a trailing slash' do
      assert_equal '/guides/start/', header('GET /guides/start?q=1 HTTP/1.1', 'Location')
    end

    it 'serves the index of the root' do
      assert_equal 'home', body('GET / HTTP/1.1')
    end

    it 'serves the index of a folder' do
      assert_equal 'start', body('GET /guides/start/ HTTP/1.1')
    end

    it 'serves a file' do
      write('site.css', 'body {}')

      assert_equal 'body {}', body('GET /site.css HTTP/1.1')
    end

    it 'gives a file the content type of its extension' do
      write('site.css', 'body {}')

      assert_equal 'text/css; charset=utf-8', header('GET /site.css HTTP/1.1', 'Content-Type')
    end

    it 'gives a file with an unknown extension a generic content type' do
      write('data.bin', 'data')

      assert_equal 'application/octet-stream', header('GET /data.bin HTTP/1.1', 'Content-Type')
    end

    it 'gives the length of the body' do
      write('mark.svg', 'é')

      assert_equal '2', header('GET /mark.svg HTTP/1.1', 'Content-Length')
    end

    it 'leaves the body out of a HEAD response' do
      assert_equal '', body('HEAD / HTTP/1.1')
    end

    it 'gives the length of the body it left out of a HEAD response' do
      assert_equal '4', header('HEAD / HTTP/1.1', 'Content-Length')
    end

    it 'answers a missing file with 404' do
      assert_equal 'HTTP/1.1 404 Not Found', status('GET /missing.html HTTP/1.1')
    end

    it 'serves 404.html for a missing file' do
      write('404.html', 'lost')

      assert_equal 'lost', body('GET /missing.html HTTP/1.1')
    end

    it 'answers a folder without an index with 404' do
      write('guides/empty/notes.txt', 'notes')

      assert_equal 'HTTP/1.1 404 Not Found', status('GET /guides/empty/ HTTP/1.1')
    end
  end
end
