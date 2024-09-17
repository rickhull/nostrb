require 'nostrb/event'
require 'nostrb/filter'
require 'nostrb/sqlite'
require 'set' # jruby wants this

# per NIP-01

module Nostrb
  class Server
    def self.event(sid, event) = ["EVENT", Nostrb.sid!(sid), event.to_h]
    def self.ok(eid, msg = "", ok: true)
      ["OK", Nostrb.id!(eid), !!ok, ok ? Nostrb.txt!(msg) : Nostrb.help!(msg)]
    end
    def self.eose(sid) = ["EOSE", Nostrb.sid!(sid)]
    def self.closed(sid, msg) = ["CLOSED", Nostrb.sid!(sid), Nostrb.help!(msg)]
    def self.notice(msg) = ["NOTICE", Nostrb.txt!(msg)]
    def self.error(e) = notice(message(e))

    def self.message(excp)
      format("%s: %s", excp.class.name.split('::').last, excp.message)
    end

    def initialize(db_filename = Storage::FILENAME)
      @reader = Reader.new(db_filename)
      @writer = Writer.new(db_filename)
    end

    # accepts a single json array
    # returns a ruby array of response strings (json array)
    def ingest(json)
      a = Nostrb.ary!(Nostrb.parse(json))
      case a[0]
      when 'EVENT'
        [handle_event(Nostrb.check!(a[1], Hash))]
      when 'REQ'
        sid = Nostrb.sid!(a[1])
        filters = a[2..-1].map { |f| Filter.ingest(f) }
        handle_req(sid, *filters)
      when 'CLOSE'
        [handle_close(Nostrb.sid!(a[1]))]
      else
        [Server.notice("unexpected: #{a[0].inspect}")]
      end
    end

    # return a single response
    def handle_event(hsh)
      begin
        hsh = SignedEvent.validate!(hsh)
      rescue Nostrb::Error, KeyError, RuntimeError => e
        return Server.error(e)
      end

      eid = hsh.fetch('id')

      begin
        @writer.add_event(SignedEvent.verify(hsh))
        Server.ok(eid)
      rescue SignedEvent::Error => e
        Server.ok(eid, Server.message(e), ok: false)
      rescue Nostrb::Error, KeyError, RuntimeError => e
        Server.error(e)
      end
    end

    # return an array of response
    # filter1:
    #   ids: [id1, id2]
    #   authors: [pubkey1]
    # filter2:
    #   ids: [id3, id4]
    #   authors: [pubkey2]

    # run filter1
    #   for any fields specified (ids, authors)
    #     if any values match, the event is a match
    #   all fields provided must match for the event to match
    #     ids must have a match and authors must have a match

    # run filter2 just like filter1
    # the result set is the union of filter1 and filter2

    def handle_req(sid, *filters)
      responses = []
      @reader.select_events.each_hash { |h|
        h = @reader.add_tags(h)
        responses << Server.event(sid, h) if filters.any? { |f| f.match? h }
      }
      responses << Server.eose(sid)
    end

    # single response
    def handle_close(sid)
      Server.closed(sid, "reason: CLOSE requested")
    end
  end
end
