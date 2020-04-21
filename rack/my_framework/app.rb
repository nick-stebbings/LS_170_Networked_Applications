
require_relative 'advice'     # loads advice.rb

class MyFramework
  def response(status, headers, body = '')
    body = yield if block_given?
    [status, headers, [body]]
  end

  def erb(filename, local = {})
    b = binding
    message = local[:message]
    content = File.read("views/#{filename}.erb")
    ERB.new(content).result(b)
  end
end

class App < MyFramework
  def call(env)
    case env['REQUEST_PATH']
    when '/'
      status = '200'
      headers = {"Content-Type" => 'text/html'}
      response(status, headers) do
        erb :index
      end
    when '/advice'
      piece_of_advice = Advice.new.generate
      status = '200'
      headers = {"Content-Type" => 'text/html'}
      response(status, headers) do
        erb :advice, message: piece_of_advice
      end
    else
      status = '404'
      headers = {"Content-Type" => 'text/html', "Content-Length" => '66'}
      response(status, headers) do
        erb :not_found
      end
    end
  end
end