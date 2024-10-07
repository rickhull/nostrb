# e.g. path/to/falcon serve --bind wss://localhost:7070

require 'async/websocket/adapters/rack'
require 'nostrb/relay'

relay = Nostrb::Relay.new
Adapter = Async::WebSocket::Adapters::Rack
config = { protocols: %w[ws wss] }

run do |env|
  Adapter.open(env, **config) do |cnx|
    cnx_id = format("[cnx:%i]", cnx.object_id)
    puts format("[%s] New connection: %s", Nostrb.timestamp, cnx_id)
    reqs, resps, t = 0, 0, Time.now
    while req = cnx.read
      reqs += 1
      puts req.buffer
      relay.ingest(req.buffer).each { |resp|
        resps += 1
        cnx.write Nostrb.json(resp)
      }
    end
    puts format("[%s] Closed %s after %.2f ms; %i req %i resp",
                Nostrb.timestamp, cnx_id, (Time.now - t) * 1000, reqs, resps)
  end
end
