require 'nostrb/relay'
require 'nostrb/source'
require_relative 'common'
require 'minitest/autorun'

include Nostrb

Test::VALID_JSON = Nostrb.json(Source.publish(Test::SIGNED))

describe Server do
  def valid_response!(resp)
    types = ["EVENT", "OK", "EOSE", "CLOSED", "NOTICE"]
    expect(resp).must_be_kind_of Array
    expect(resp.length).must_be :>=, 2
    expect(resp.length).must_be :<=, 4
    resp[0..1].each { |s| expect(s).must_be_kind_of String }
    expect(resp[0].upcase).must_equal resp[0]
    expect(types.include?(resp[0])).must_equal true
  end

  describe "class functions" do
    it "has an EVENT response, given subscriber_id and requested event" do
      sid = '1234'
      resp = Server.event(sid, Test::SIGNED)
      valid_response!(resp)
      expect(resp[0]).must_equal "EVENT"
      expect(resp[1]).must_equal sid
      expect(resp[2]).must_be_kind_of Hash
      expect(resp[2]).wont_be_empty
    end

    it "has an OK response, given an event_id" do
      # positive ok
      resp = Server.ok(Test::SIGNED.id)
      valid_response!(resp)
      expect(resp[0]).must_equal "OK"
      expect(resp[1]).must_equal Test::SIGNED.id
      expect(resp[2]).must_equal true
      expect(resp[3]).must_be_kind_of String # empty by default

      # negative ok
      resp = Server.ok(Test::SIGNED.id, "error: testing", ok: false)
      valid_response!(resp)
      expect(resp[0]).must_equal "OK"
      expect(resp[1]).must_equal Test::SIGNED.id
      expect(resp[2]).must_equal false
      expect(resp[3]).must_be_kind_of String
      expect(resp[3]).wont_be_empty

      # ok:false requires nonempty message
      expect { Server.ok(Test::SIGNED.id, "", ok: false) }.must_raise FormatError
      expect { Server.ok(Test::SIGNED.id, ok: false) }.must_raise FormatError
    end

    it "has an EOSE response to conclude a series of EVENT responses" do
      sid = '1234'
      resp = Server.eose(sid)
      valid_response!(resp)
      expect(resp[0]).must_equal "EOSE"
      expect(resp[1]).must_equal sid
    end

    it "has a CLOSED response to shut down a subscriber" do
      sid = '1234'
      msg = "closed: bye"
      resp = Server.closed(sid, msg)
      valid_response!(resp)
      expect(resp[0]).must_equal "CLOSED"
      expect(resp[1]).must_equal sid
      expect(resp[2]).must_equal msg
    end

    it "has a NOTICE response to provide any message to the user" do
      msg = "all i ever really wanna do is get nice, " +
            "get loose and goof this little slice of life"
      resp = Server.notice(msg)
      valid_response!(resp)
      expect(resp[0]).must_equal "NOTICE"
      expect(resp[1]).must_equal msg
    end

    it "formats Exceptions to a common string representation" do
      r = RuntimeError.new("stuff")
      expect(r).must_be_kind_of Exception
      expect(Server.message(r)).must_equal "RuntimeError: stuff"

      e = Nostrb::Error.new("things")
      expect(e).must_be_kind_of Exception
      expect(Server.message(e)).must_equal "Error: things"
    end

    it "uses NOTICE to return errors" do
      e = RuntimeError.new "stuff"
      resp = Server.error(e)
      valid_response!(resp)
      expect(resp[0]).must_equal "NOTICE"
      expect(resp[1]).must_equal "RuntimeError: stuff"
    end
  end

  it "has no initialization parameters" do
    s = Server.new
    expect(s).must_be_kind_of Server
  end

  it "stores inbound events" do
    s = Server.new
    s.ingest(Nostrb.json(Source.publish(Test::SIGNED)))
    events = s.events
    expect(events).must_be_kind_of Array
    expect(events.length).must_equal 1
    hsh = events[0]
    expect(hsh).must_be_kind_of Hash
    expect(hsh).must_equal Test::SIGNED.to_h
  end

  it "has a single response to EVENT requests" do
    # respond OK: true
    responses = Server.new.ingest(Test::VALID_JSON)
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "OK"
    expect(resp[1]).must_equal Test::SIGNED.id
    expect(resp[2]).must_equal true
  end

  it "rejects unknown request types" do
    # invalid request type: respond error / NOTICE
    ary = Nostrb.parse(Test::VALID_JSON)
    ary[0] = ary[0].downcase
    responses = Server.new.ingest(Nostrb.json(ary))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "NOTICE"
    expect(resp[1]).must_be_kind_of String
    expect(resp[1]).wont_be_empty
  end

  it "rejects events with missing fields" do
    # event missing "id": respond error / NOTICE
    ary = Nostrb.parse(Test::VALID_JSON)
    hsh = ary[1]
    hsh.delete("id")
    ary[1] = hsh
    responses = Server.new.ingest(Nostrb.json(ary))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "NOTICE"
    expect(resp[1]).must_be_kind_of String
    expect(resp[1]).wont_be_empty
  end

  it "rejects events with invalid format" do
    # short signature: response error / NOTICE
    ary = Nostrb.parse(Test::VALID_JSON)
    hsh = ary[1]
    hsh["sig"] = SchnorrSig.bin2hex(Random.bytes(32))
    ary[1] = hsh
    responses = Server.new.ingest(Nostrb.json(ary))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "NOTICE"
    expect(resp[1]).must_be_kind_of String
    expect(resp[1]).wont_be_empty
  end

  it "rejects events with invalid signature" do
    # invalid signature, respond OK: false
    ary = Nostrb.parse(Test::VALID_JSON)
    hsh = ary[1]
    hsh["sig"] = SchnorrSig.bin2hex(Random.bytes(64))
    ary[1] = hsh
    responses = Server.new.ingest(Nostrb.json(ary))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "OK"
    expect(resp[1]).must_equal hsh["id"]
    expect(resp[2]).must_equal false
    expect(resp[3]).must_be_kind_of String
    expect(resp[3]).wont_be_empty
  end

  it "rejects events with invalid id" do
    # invalid id, respond OK: false
    ary = Nostrb.parse(Test::VALID_JSON)
    hsh = ary[1]
    hsh["id"] = SchnorrSig.bin2hex(Random.bytes(32))
    ary[1] = hsh
    responses = Server.new.ingest(Nostrb.json(ary))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "OK"
    expect(resp[1]).must_equal hsh["id"]
    expect(resp[2]).must_equal false
    expect(resp[3]).must_be_kind_of String
    expect(resp[3]).wont_be_empty
  end

  it "has multiple responses to REQ requets" do
    # ingest 2 events (Source.publish)
    # get a subscription request (Source.subscribe)
    # respond EVENT
    # respond EVENT
    # respond EOSE

    s = Server.new
    e1 = Event.new('one', pk: Test::PK).sign(Test::SK)
    e2 = Event.new('two', pk: Test::PK).sign(Test::SK)
    [e1, e2].each { |e|
      responses = s.ingest(Nostrb.json(Source.publish(e)))
      expect(responses).must_be_kind_of Array
      expect(responses.length).must_equal 1
      resp = responses[0]
      expect(resp).must_be_kind_of Array
      expect(resp[0]).must_equal "OK"
      expect(resp[1]).must_equal e.id
      expect(resp[2]).must_equal true
    }

    # with no filters, nothing will match
    sid = e1.pubkey
    responses = s.ingest(Nostrb.json(Source.subscribe(sid)))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1
    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "EOSE"
    expect(resp[1]).must_equal sid

    # now add a filter based on pubkey
    f = Filter.new
    f.add_authors e1.pubkey

    responses = s.ingest(Nostrb.json(Source.subscribe(sid, f)))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 3

    # remove EOSE and validate
    eose = responses.pop
    expect(eose).must_be_kind_of Array
    expect(eose[0]).must_equal "EOSE"
    expect(eose[1]).must_equal sid

    responses.each { |event|
      expect(event).must_be_kind_of Array
      expect(event[0]).must_equal "EVENT"
      expect(event[1]).must_equal sid
      hsh = event[2]
      expect(hsh).must_be_kind_of Hash
      expect(SignedEvent.validate!(hsh)).must_equal hsh
    }
    expect(responses[0][2]).must_equal e1.to_h
    expect(responses[1][2]).must_equal e2.to_h
  end

  it "has a single response to CLOSE requests" do
    s = Server.new
    sid = Test::EVENT.pubkey
    responses = s.ingest(Nostrb.json(Source.close(sid)))

    # respond CLOSED
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "CLOSED"
    expect(resp[1]).must_equal sid
  end
end
