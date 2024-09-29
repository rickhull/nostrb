# path/to/falcon serve \
#   --bind wss://localhost:7070 \
#   --config examples/config.ru \

require 'async/websocket/adapters/rack'
require 'nostrb/relay'

relay = Nostrb::Server.new
Adapter = Async::WebSocket::Adapters::Rack

app = lambda do |env|
  Adapter.open(env, protocols: ['ws', 'wss']) do |conn|
    puts "New connection: #{conn}"
    reqs, resps = 0, 0
    while req = conn.read
      reqs += 1
      puts req.buffer
      relay.ingest(req.buffer).each { |resp|
        resps += 1
        conn.write Nostrb.json(resp)
      }
    end
    puts "Closed after #{reqs} requests and #{resps} responses"
  end
end

run app
