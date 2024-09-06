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

    attr_reader :events, :subs

    def initialize
      @events = [] # all events accepted
      @buffer = []
    end

    # accepts a single json array
    # returns a ruby array of json arrays
    def ingest(json)
      a = Nostr.ary!(Nostr.parse(json))
      case a[0]
      when 'EVENT'
        handle_event(Nostr.check!(a[1], Hash))
      when 'REQ'
        sid = Nostr.sid!(a[1])
        filters = a[2..-1].map { |f| Filter.ingest(f) }
        handle_req(sid, *filters)
      when 'CLOSE'
        handle_close(Nostr.sid!(a[1]))
      else
        raise 'unexpected'
      end
      buffer, @buffer = @buffer, []
      buffer.map { |a| Nostr.json a }
    end

    def handle_event(hsh)
      begin
        hsh = SignedEvent.validate!(hsh)
        eid = hsh.fetch("id")
        @events << hsh
        @buffer << Server.ok(eid)
      rescue SignedEvent::Error => e
        @buffer << Server.ok(eid, Server.message(e), ok: false)
      rescue Nostr::Error, KeyError => e
        @buffer << Server.error(e)
      rescue RuntimeError => e
        @buffer << Server.error(e)
      end
    end

    def handle_req(sid, *filters)
      results = []
      @events.each { |e|
        match = false
        filters.each { |f|
          next if match
          match = f.match?(e)
        }
        results << e if match
      }
      results.each { |e| @buffer << Server.event(sid, e) }
      @buffer << Server.eose(sid)
    end

    def handle_close(sid)
      @buffer << Server.closed(sid, "CLOSE requested")
    end
  end
end
