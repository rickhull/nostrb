require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'

require 'nostrb/source'

url = 'wss://localhost:7070'

sk, pk = SchnorrSig.keypair
src = Nostrb::Source.new(pk)

puts "Relay URL: #{url}"
puts "Enter messages to send to the relay (empty line to quit):"

Async do |task|
  endpoint = Async::HTTP::Endpoint.parse(url)

  Async::WebSocket::Client.connect(endpoint) do |conn|
    input_task = task.async do
      while line = $stdin.gets
        str = line.chomp
        break if str.empty?
        event = src.text_note(str).sign(sk)
        json = Nostrb.json(Nostrb::Source.publish(event))
        conn.write(json)
        conn.flush
      end
      task.stop
    end

    while !input_task.completed?
      resp = conn.read
      puts resp.buffer
    end
  ensure
    input_task&.stop
  end
end
