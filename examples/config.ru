# path/to/falcon serve \
#   --bind wss://localhost:7070 \
#   --config examples/config.ru \

require 'async/websocket/adapters/rack'
require 'nostrb/relay'

relay = Nostrb::Server.new
Adapter = Async::WebSocket::Adapters::Rack

app = lambda do |env|
  Adapter.open(env, protocols: ['ws', 'wss']) do |conn|
    while msg = conn.read
      puts msg.buffer
      relay.ingest(msg.buffer).each { |resp|
        conn.write Nostrb.json(resp)
      }
    end
  end
end

run app
