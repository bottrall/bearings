# frozen_string_literal: true

require 'test_helper'
require 'socket'

describe Bearings::NetHttp do
  before do
    @server = TCPServer.new('127.0.0.1', 0)
    @url = "http://127.0.0.1:#{@server.addr[1]}"
  end

  after do
    @thread&.kill
    @server.close unless @server.closed?
  end

  def respond(*heads)
    @thread = Thread.new do
      heads.each do |head|
        client = @server.accept
        nil while client.gets != "\r\n"
        client.write("HTTP/1.1 #{head}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        client.close
      end
    end
  end

  def hang
    @thread = Thread.new do
      client = @server.accept
      sleep
    ensure
      client&.close
    end
  end

  def redirect(path) = "302 Found\r\nLocation: #{path}"

  def failure(reason, timed_out: false) = Bearings::Checks::ExternalLinks::Failure.new(reason:, timed_out:)

  describe '.status' do
    it 'gives a URL that is not http or https as a failure' do
      assert_equal failure('ftp://files.example/a is not an http or https URL'),
                   Bearings::NetHttp.status('ftp://files.example/a')
    end

    it 'gives the status of a response that is not a redirect' do
      respond('404 Not Found')

      assert_equal 404, Bearings::NetHttp.status(@url)
    end

    it 'gives the status of a redirect with no location' do
      respond('302 Found')

      assert_equal 302, Bearings::NetHttp.status(@url)
    end

    it 'follows a redirect to its target' do
      respond(redirect('/moved'), '200 OK')

      assert_equal 200, Bearings::NetHttp.status(@url)
    end

    it 'gives up after five redirects' do
      respond(*Array.new(6) { redirect('/again') })

      assert_equal failure('redirected more than 5 times'), Bearings::NetHttp.status(@url)
    end

    it 'gives a timeout as a timed-out failure' do
      hang

      assert_equal failure('timed out after 0.1s', timed_out: true), Bearings::NetHttp.status(@url, timeout: 0.1)
    end

    it 'gives a refused connection as a failure that did not time out' do
      @server.close

      refute Bearings::NetHttp.status(@url).timed_out
    end
  end
end
