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

    # open, send req, get response, close, return response
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

    def publish(edata)
      case single(Nostrb::Source.publish(edata))
      in ['OK', String => event_id, ok, String => msg]
        log "id mismatch: #{event_id}" unless event_id == edata.id
        log msg unless ok
        ok
      in ['NOTICE', String => msg]
        log msg
      end
    end

    # yields SignedEvent
    def subscribe(*filters, &blk)
      Sync do
        Async::WebSocket::Client.connect(@endpoint) do |conn|
          conn.write(Nostrb.json(Nostrb::Source.subscribe(@sid, *filters)))
          conn.flush
          eose = false
          while !eose and resp = conn.read
            case Nostrb.parse(resp.buffer)
            in ['EVENT', String => sid, Hash => hsh]
              log "sid mismatch: #{sid}" unless sid == @sid
              yield SignedEvent.ingest(hsh)
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
