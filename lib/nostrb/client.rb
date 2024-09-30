require 'set'

require 'async'
require 'async/http/endpoint'
require 'async/websocket/client'

require 'nostrb/source'



module Nostrb
  class Client
    def self.get(conn, msg)
      conn.write(Nostrb.json(msg))
      conn.flush
      resp = conn.read
      conn.shutdown
    end

    attr_reader :url, :endpoint, :sid

    def initialize(relay_url, sid: nil)
      @url = relay_url
      @endpoint = Async::HTTP::Endpoint.parse(@url)
      @sid = sid.nil? ? Source.random_sid : sid
    end

    def log msg
      warn msg
    end

    def publish(signed_event)
      resp = nil
      Sync do
        Async::WebSocket::Client.connect(@endpoint) do |conn|
          Nostrb::Client.get(conn, Nostrb::Source.publish(signed_event))
        end
      end
      if resp
        ary = Nostrb.parse(resp.buffer)
        # 0: OK
        # 1: event id
        # 2: true or false
        # 3: message, typically for OK:false
        case ary[0]
        when 'OK'
          log "id mismatch: #{ary[1]}" unless ary[1] == signed_event.id
          log ary[3] unless ary[2]
          ary[2] # true / false
        when 'NOTICE'
          log ary[1] # error
        else
          raise('unexpected')
        end
      end
    end

    def subscribe(*filters, &blk)
      Sync do
        Async::WebSocket::Client.connect(@endpoint) do |conn|
          conn.write(Nostrb.json(Nostrb::Source.subscribe(@sid, *filters)))
          conn.flush
          eose = false
          while !eose and resp = conn.read
            ary = Nostrb.parse(resp.buffer)
            case ary[0]
            when 'EVENT'
              yield ary[2]
            when 'EOSE'
              eose = true
            else
              raise('unexpected')
            end
          end
          conn.shutdown
        end
      end
    end

    def close
      resp = nil
      Sync do
        Async::WebSocket::Client.connect(@endpoint) do |conn|
          Nostrb::Client.get(conn, Nostrb::Source.close(@sid))
        end
      end
      if resp
        ary = Nostrb.parse(resp.buffer)
        case ary[0]
        when 'CLOSED'
          if !ary[1].empty?
            log ary[1]
          end
          true
        else
          raise('unexpected')
        end
      end
    end
  end
end

if __FILE__ == $0
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
end
