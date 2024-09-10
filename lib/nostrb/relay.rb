require 'nostrb/event'

# per NIP-01

module Nostr
  class Server
    def self.event(sid, event) = ["EVENT", Nostr.sid!(sid), event.to_h]
    def self.ok(eid, msg = "", ok: true)
      ["OK", Nostr.id!(eid), !!ok, ok ? Nostr.txt!(msg) : Nostr.help!(msg)]
    end
    def self.eose(sid) = ["EOSE", Nostr.sid!(sid)]
    def self.closed(sid, msg) = ["CLOSED", Nostr.sid!(sid), Nostr.help!(msg)]
    def self.notice(msg) = ["NOTICE", Nostr.txt!(msg)]
    def self.message(excp) = format("%s: %s", excp.class, excp.message)
    def self.error(e) = notice(message(e))

    def initialize
      @events = {} # { pubkey => [event_hash] }
    end

    # accepts a single json array
    # returns a ruby array of response strings (json array)
    def ingest(json)
      a = Nostr.ary!(Nostr.parse(json))
      case a[0]
      when 'EVENT'
        [handle_event(Nostr.check!(a[1], Hash))]
      when 'REQ'
        sid = Nostr.sid!(a[1])
        filters = a[2..-1].map { |f| Filter.ingest(f) }
        handle_req(sid, *filters)
      when 'CLOSE'
        [handle_close(Nostr.sid!(a[1]))]
      else
        raise 'unexpected'
      end
    end

    # update @events, keyed by pubkey
    def add_event(hsh)
      pubkey = hsh.fetch "pubkey"
      if @events[pubkey]
        @events[pubkey] << hsh
      else
        @events[pubkey] = [hsh]
      end
      self
    end

    # return a single response
    def handle_event(hsh)
      begin
        hsh = SignedEvent.validate!(hsh) # only raises Nostr::Error
      rescue Nostr::Error, KeyError, RuntimeError => e
        Server.error(e)
      end

      eid = hsh.fetch('id')

      begin
        add_event(hsh)
        Server.ok(eid)
      rescue SignedEvent::Error => e
        Server.ok(eid, Server.message(e), ok: false)
      rescue Nostr::Error, KeyError, RuntimeError => e
        Server.error(e)
      end
    end

    # return an array of events, matching pubkey if provided
    def events(pubkey: nil)
      if !pubkey.nil?
        return [] unless (ary = @events[pubkey])
        ary
      else
        @events.values.flatten
      end
    end

    # return an array of response
    def handle_req(sid, *filters)
      responses = []
      events = []
      filters.each { |f|
        if f.authors.empty?
          events += self.events
        else
          f.authors.each { |pub|
            events += self.events(pubkey: pub)
          }
        end
      }

      events.each { |h|
        match = false
        filters.each { |f|
          next if match
          match = f.match?(h)
        }
        responses << Server.event(sid, h) if match
      }
      responses << Server.eose(sid)
    end

    # single response
    def handle_close(sid)
      Server.closed(sid, "CLOSE requested")
    end
  end
end
