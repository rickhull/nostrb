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
    reqs, resps, t = 0, 0, Time.now
    while req = conn.read
      reqs += 1
      puts req.buffer
      relay.ingest(req.buffer).each { |resp|
        resps += 1
        conn.write Nostrb.json(resp)
      }
    end
    puts format("Closed after %.3f s; %i req %i resp",
                Time.now - t, reqs, resps)
  end
end

run app
