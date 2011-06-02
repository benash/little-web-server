require 'socket'
require 'filemagic'

class Request

  attr_reader :method, :request_uri, :http_version, :headers, :body

  def initialize(socket)
    init_request_line(socket)
    init_headers(socket)
    init_body(socket)
  end

  def init_request_line(sock)
    @method, @request_uri, @http_version = sock.gets.split
  end

  def init_headers(socket)
    @headers = Headers.new
    @headers.read(socket)
  end

  def init_body(sock)

    if @method == "POST"
      @body = PostData.new(sock.read(get_content_length))
    end

  end

  def get_content_length
    @headers.data["Content-Length"].to_i
  end

  def get_filename
    if @request_uri[-1] == "/"
      @request_uri += "index.html"
    end

    if @request_uri[0] == "/"
      @request_uri = "." + @request_uri
    end
  end

  def to_s
    "#{@method} #{@request_uri} #{@http_version}\n#{@headers}#{@body}\n"
  end
end

class PostData

  def initialize(body)
    @data = {}
    body.split("&").each { |part|
      key, value = part.split("=")
      @data[key] = value.gsub("+", " ")
    }
  end

  def to_s
    @data.collect {|key, value|
      "#{key} = #{value}\n"
    }.join
  end

end

class Headers

  @@DELIMETER = ":"

  attr_reader :data

  def initialize
    @data = {}
  end

  def add(key, value)
    @data[key] = value
  end

  def read(socket)
    loop do
      line = socket.gets
      if line.strip.empty?
        break
      end
      key, value = line.split(@@DELIMETER, 2)
      add(key, value)
    end
  end
    
  def to_s
    @data.collect {|key, value| 
      "#{key.strip}#{@@DELIMETER} #{value.strip}\n" 
    }.join
  end

end

class Response

  def initialize
    @http_version = "HTTP/1.1"
    @status_code = "200"
    @reason_phrase = "OK"
    @response_headers = Headers.new
    @body = 'Nothing to see here'
  end

  def set_status(status_code, reason_phrase)
    @status_code = status_code
    @reason_phrase = reason_phrase
  end

  def get_status_line
    @http_version + ' ' + @status_code + ' ' + @reason_phrase + "\n"
  end

  def set_body(body)
    @body = body
  end

  def add_header(key, value)
    @response_headers.add(key, value)
  end

  def head
    get_status_line + "#{@response_headers}\n"
  end

  def to_s 
    "#{head}#{@body}"
  end

end

class HttpServer < TCPServer

  def initialize
    super(80)
    @magic = FileMagic.mime
  end

  def start
    loop do
      socket = accept
      request = Request.new(socket)
      STDOUT.puts request

      response = respond_to_request(request)

      socket.puts response
      STDOUT.puts response.head

      socket.close
    end
  end

  def stop
    shutdown
  end

  def respond_to_request(req)

    response = Response.new
    filename = req.get_filename
    mime_type = @magic.file(filename)
    file = File.new(filename)
    data = file.read

    response.set_body(data)
    response.add_header("Content-Type", mime_type)

    response

  end

end


