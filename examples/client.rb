require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'

require 'nostrb/source'

url = 'wss://localhost:7070'
endpoint = Async::HTTP::Endpoint.parse(url)

sk, pk = SchnorrSig.keypair
src = Nostrb::Source.new(pk)

puts "Relay URL: #{url}"
puts "Pubkey: #{SchnorrSig.bin2hex pk}"
puts "Enter messages to send to the relay (empty line to quit):"

Async do
  Async::WebSocket::Client.connect(endpoint) do |conn|
    while line = $stdin.gets and line != "\n"
      event = src.text_note(line.chomp).sign(sk)
      json = Nostrb.json(Nostrb::Source.publish(event))
      conn.write(json)
      conn.flush
      resp = conn.read
      puts resp.buffer
    end
    conn.shutdown  # eliminate ECONNRESET on the server end
  end
end
