require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'

require 'nostrb/source'

module Nostrb
  class Client
    attr_reader :url, :endpoint, :sid

    def initialize(relay_url, sid: nil)
      @url = relay_url
      @endpoint = Async::HTTP::Endpoint.parse(@url)
      @sid = sid.nil? ? Source.random_sid : sid
    end

    def log msg
      warn msg
    end

    # open, send req, get response, return response
    def single(req)
      Sync do
        Async::WebSocket::Client.connect(@endpoint) do |conn|
          conn.write(Nostrb.json(req))
          conn.flush
          resp = conn.read
          conn.shutdown
          Nostrb.parse(resp.buffer)
        end
      end
    end

    def publish(signed_event)
      case single(Nostrb::Source.publish(signed_event))
      in ['OK', String => event_id, ok, String => msg]
        log "id mismatch: #{event_id}" unless event_id == signed_event.id
        log msg unless ok
        ok
      in ['NOTICE', String => msg]
        log msg
      end
    end

    def subscribe(*filters, &blk)
      Sync do
        Async::WebSocket::Client.connect(@endpoint) do |conn|
          conn.write(Nostrb.json(Nostrb::Source.subscribe(@sid, *filters)))
          conn.flush
          eose = false
          while !eose and resp = conn.read
            case Nostrb.parse(resp.buffer)
            in ['EVENT', String => sid, Hash => event]
              log "sid mismatch: #{sid}" unless sid == @sid
              yield event
            in ['EOSE', String => sid]
              log "sid mismatch: #{sid}" unless sid == @sid
              eose = true
            end
          end
          conn.shutdown
        end
      end
    end

    def close
      case single(Nostrb::Source.close(@sid))
      in ['CLOSED', String => sid, String => msg]
        log "sid mismatch: #{sid}" unless sid == @sid
        log msg unless msg.empty?
        true
      end
    end
  end
end

if __FILE__ == $0
  require 'set'
  c = Nostrb::Client.new('wss://localhost:7070')
  sk, pk = SchnorrSig.keypair
  src = Nostrb::Source.new(pk)

  tag = SchnorrSig.bin2hex Random.bytes(4)

  p = src.profile(name: "testing-#{tag}", about: tag, picture: tag).sign(sk)
  puts "profile: #{p}"
  puts c.publish(p)

  e = src.text_note('hello world').sign(sk)
  puts "event: #{e}"
  puts c.publish(e)

  # who else is out there?
  # subscribe to kind:0 events in the last year
  # gather pubkeys

  pubkeys = Set.new

  f = Nostrb::Filter.new
  f.add_kinds 0
  f.since = Nostrb::Filter.ago(years: 1)

  puts "filter: #{f}"
  c.subscribe(f) { |e| pubkeys.add e.fetch('pubkey') }
  p pubkeys.to_a

  puts "close:"
  c.close
end
