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
        # raise e
        [Relay.error(e)]
      end
    end

    # return a single response
    def handle_event(hsh)
      begin
        edata = SignedEvent.ingest(hsh)
      rescue Nostrb::Error, KeyError, RuntimeError => e
        return Relay.error(e)
      end

      if !edata.valid_id?
        return Relay.ok(edata.id, "IdCheck: #{edata.id}", ok: false)
      elsif !edata.valid_sig?
        return Relay.ok(edata.id, "SigCheck: #{edata.sig}", ok: false)
      end

      begin
        case edata.kind
        when 1, (4..44), (1000..9999)
          # regular, store all
          @writer.add_event(edata)
        when 0, 3, (10_000..19_999)
          # replaceable, store latest (pubkey, kind)
          @writer.add_r_event(edata)
        when 20_000..29_999
          # ephemeral, don't store
        when 30_000..30_999
          # parameterized replaceable, store latest (pubkey, kind, dtag)
          @writer.add_r_event(edata)
        else
          return Relay.ok(edata.id, "kind: #{edata.kind}", ok: false)
        end
        Relay.ok(edata.id)
      rescue RuntimeError => e
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

    # TODO: parallel processing across events/r_events and filters?
    #       long subscription polling?
    def handle_req(sid, *filters)
      responses = Set.new

      filters.each { |f|
        events = @reader.select_events(f, table: 'events')
        while (next_event = events.next)
          edata = SQLite::Reader.hydrate(next_event)
          responses << Relay.event(sid, edata) if f.match? edata
          next_event = events.next
        end

        r_events = @reader.select_events(f, table: 'r_events')
        while (next_r_event = r_events.next)
          redata = SQLite::Reader.hydrate(next_r_event)
          responses << Relay.event(sid, redata) if f.match? redata
          next_r_event = r_events.next
        end
      }
      responses = responses.to_a
      responses << Relay.eose(sid)
    end

    # single response
    def handle_close(sid)
      # TODO: stuff here with long subs
      Relay.closed(sid, "reason: CLOSE requested")
    end
  end
end
