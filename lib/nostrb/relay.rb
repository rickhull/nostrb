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

    attr_reader :events

    def initialize
      @events = [] # all events accepted
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

    # return a single response
    def handle_event(hsh)
      begin
        hsh = SignedEvent.validate!(hsh)
        eid = hsh.fetch("id")
        @events << hsh
        Server.ok(eid)
      rescue SignedEvent::Error => e
        Server.ok(eid, Server.message(e), ok: false)
      rescue Nostr::Error, KeyError => e
        Server.error(e)
      rescue RuntimeError => e
        Server.error(e)
      end
    end

    # return an array of response
    def handle_req(sid, *filters)
      responses = []
      @events.each { |e|
        match = false
        filters.each { |f|
          next if match
          match = f.match?(e)
        }
        responses << Server.event(sid, e) if match
      }
      responses << Server.eose(sid)
    end

    # single response
    def handle_close(sid)
      Server.closed(sid, "CLOSE requested")
    end
  end
end
