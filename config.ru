# e.g. path/to/falcon serve --bind wss://localhost:7070

require 'async/websocket/adapters/rack'
require 'nostrb/relay'

relay = Nostrb::Relay.new
Adapter = Async::WebSocket::Adapters::Rack

app = lambda do |env|
  Adapter.open(env, protocols: ['ws', 'wss']) do |conn|
    cnx_id = format("[cnx:%i]", conn.object_id)
    puts format("New connection: %s", cnx_id)
    reqs, resps, t = 0, 0, Time.now
    while req = conn.read
      reqs += 1
      puts req.buffer
      relay.ingest(req.buffer).each { |resp|
        resps += 1
        conn.write Nostrb.json(resp)
      }
    end
    puts format("Closed %s after %.3f s; %i req %i resp",
                cnx_id, Time.now - t, reqs, resps)
  end
end

run app
