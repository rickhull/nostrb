require 'nostrb/event'
require 'nostrb/filter'
require 'nostrb/sqlite'
require 'set' # jruby wants this

# Kind:
#   1,4..44,1000..9999: regular -- relay stores all
#   0,3: replaceable -- relay stores only the last message from pubkey
#   2: deprecated
#   10_000..19_999: replaceable -- relay stores latest(pubkey, kind)
#   20_000..29_999: ephemeral -- relay doesn't store
#   30_000..39_999: parameterized replaceable -- latest(pubkey, kind, dtag)

# for replaceable events with same timestamp, lowest id wins

module Nostrb
  class Relay
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

    def initialize(db_filename = nil, storage: :sqlite)
      case storage
      when :sqlite
        mod = Nostrb::SQLite
      when :sequel
        require 'nostrb/sequel'
        mod = Nostrb::Sequel
      else
        raise "unexpected: #{storage.inspect}"
      end
      db_filename ||= mod::Storage::FILENAME
      @reader = mod::Reader.new(db_filename)
      @writer = mod::Writer.new(db_filename)
    end

    # accepts a single json array
    # returns a ruby array of response strings (json array)
    def ingest(json)
      begin
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
          [Relay.notice("unexpected: #{a[0].inspect}")]
        end
      rescue StandardError => e
        [Relay.error(e)]
      end
    end

    # return a single response
    def handle_event(hsh)
      begin
        hsh = SignedEvent.validate!(hsh)
      rescue Nostrb::Error, KeyError, RuntimeError => e
        return Relay.error(e)
      end

      eid = hsh['id']

      begin
        hsh = SignedEvent.verify(hsh)
        case hsh['kind']
        when 1, (4..44), (1000..9999)
          # regular, store all
          @writer.add_event(hsh)
        when 0, 3, (10_000..19_999)
          # replaceable, store latest (pubkey, kind)
          @writer.add_r_event(hsh)
        when 20_000..29_999
          # ephemeral, don't store
        when 30_000..30_999
          # parameterized replaceable, store latest (pubkey, kind, dtag)
          @writer.add_r_event(hsh)
        else
          raise(SignedEvent::Error, "kind: #{hsh['kind']}")
        end

        Relay.ok(eid)
      rescue SignedEvent::Error => e
        Relay.ok(eid, Relay.message(e), ok: false)
      rescue Nostrb::Error, KeyError, RuntimeError => e
        Relay.error(e)
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
      responses = Set.new

      filters.each { |f|
        @reader.process_events(f).each { |h|
          responses << Relay.event(sid, h) if f.match? h
        }
        @reader.process_r_events(f).each { |h|
          responses << Relay.event(sid, h) if f.match? h
        }
      }
      responses = responses.to_a
      responses << Relay.eose(sid)
    end

    # single response
    def handle_close(sid)
      Relay.closed(sid, "reason: CLOSE requested")
    end
  end
end
