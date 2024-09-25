require 'nostrb/relay'
require 'nostrb/source'
require_relative 'common'
require 'minitest/autorun'

include Nostrb


# this can be set by GitHubActions
DB_FILE = ENV['INPUT_DB_FILE'] || 'testing.db'

# use SQLite backing
SQLite::Setup.new(DB_FILE).setup

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
      expect {
        Server.ok(Test::SIGNED.id, "", ok: false)
      }.must_raise FormatError
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
    s = Server.new(DB_FILE)
    expect(s).must_be_kind_of Server
  end

  # respond OK: true
  it "has a single response to EVENT requests" do
    json = Nostrb.json(Source.publish(Test::SIGNED))
    responses = Server.new(DB_FILE).ingest(json)
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1

    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "OK"
    expect(resp[1]).must_equal Test::SIGNED.id
    expect(resp[2]).must_equal true
  end

  # store and retrieve with a subscription filter
  it "stores inbound events" do
    s = Server.new(DB_FILE)
    sk, pk = SchnorrSig.keypair
    e = Event.new('sqlite', pk: pk).sign(sk)
    resp = s.ingest Nostrb.json(Source.publish(e))
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_be_kind_of Array
    expect(resp[0][0]).must_equal "OK"

    pubkey = SchnorrSig.bin2hex(pk)

    f = Filter.new
    f.add_authors pubkey
    f.add_ids e.id

    resp = s.ingest Nostrb.json(Source.subscribe(pubkey, f))
    expect(resp).must_be_kind_of Array
    expect(resp.length).must_equal 2
    event, eose = *resp
    expect(event[0]).must_equal 'EVENT'
    expect(event[1]).must_equal pubkey
    expect(event[2]).must_be_kind_of Hash
    expect(event[2]['id']).must_equal e.id
    expect(eose[0]).must_equal 'EOSE'
  end

  it "has multiple responses to REQ requets" do
    s = Server.new(DB_FILE)
    sk, pk = SchnorrSig.keypair
    e = Event.new('first', pk: pk).sign(sk)
    resp = s.ingest Nostrb.json(Source.publish(e))
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_be_kind_of Array
    expect(resp[0][0]).must_equal "OK"

    e2 = Event.new('second', pk: pk).sign(sk)
    resp = s.ingest Nostrb.json(Source.publish(e2))
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_be_kind_of Array
    expect(resp[0][0]).must_equal "OK"

    # with no filters, nothing will match
    sid = e.pubkey
    responses = s.ingest(Nostrb.json(Source.subscribe(sid)))
    expect(responses).must_be_kind_of Array
    expect(responses.length).must_equal 1
    resp = responses[0]
    expect(resp).must_be_kind_of Array
    expect(resp[0]).must_equal "EOSE"
    expect(resp[1]).must_equal sid

    # now add a filter based on pubkey
    f = Filter.new
    f.add_authors e.pubkey
    f.add_ids e.id, e2.id

    resp = s.ingest Nostrb.json(Source.subscribe(sid, f))
    expect(resp).must_be_kind_of Array
    expect(resp.length).must_equal 3

    # remove EOSE and validate
    eose = resp.pop
    expect(eose).must_be_kind_of Array
    expect(eose[0]).must_equal "EOSE"
    expect(eose[1]).must_equal sid

    # verify the response event ids
    resp.each { |event|
      expect(event).must_be_kind_of Array
      expect(event[0]).must_equal "EVENT"
      expect(event[1]).must_equal sid
      hsh = event[2]
      expect(hsh).must_be_kind_of Hash
      expect(SignedEvent.validate!(hsh)).must_equal hsh
      expect([e.id, e2.id]).must_include hsh["id"]
    }
  end

  it "has a single response to CLOSE requests" do
    s = Server.new(DB_FILE)
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

  describe "error handling" do
    # invalid request type
    it "handles unknown unknown request types with an error notice" do
      a = Source.publish Test::SIGNED
      a[0] = 'NONSENSE'
      responses = Server.new(DB_FILE).ingest(Nostrb.json(a))
      expect(responses).must_be_kind_of Array
      expect(responses.length).must_equal 1

      resp = responses[0]
      expect(resp).must_be_kind_of Array
      expect(resp[0]).must_equal "NOTICE"
      expect(resp[1]).must_be_kind_of String
      expect(resp[1]).wont_be_empty
    end

    # replace leading open brace with space
    it "handles JSON parse errors with an error notice" do
      j = Nostrb.json(Nostrb::Source.publish(Test::SIGNED))
      expect(j[9]).must_equal '{'
      j[9] = ' '
      resp = Server.new(DB_FILE).ingest(j)
      expect(resp).must_be_kind_of Array
      expect(resp.length).must_equal 1

      type, msg = *resp.first
      expect(type).must_equal "NOTICE"
      expect(msg).must_be_kind_of String
      expect(msg).wont_be_empty
    end

    # add "stuff":"things"
    it "handles unexpected fields with an error notice" do
      a = Nostrb::Source.publish(Test::SIGNED)
      expect(a[1]).must_be_kind_of Hash
      a[1]["stuff"] = "things"

      resp = Server.new(DB_FILE).ingest(Nostrb.json(a))
      expect(resp).must_be_kind_of Array
      expect(resp.length).must_equal 1

      type, msg = *resp.first
      expect(type).must_equal "NOTICE"
      expect(msg).must_be_kind_of String
      expect(msg).wont_be_empty
    end

    # remove "tags"
    it "handles missing fields with an error notice" do
      a = Nostrb::Source.publish(Test::SIGNED)
      expect(a[1]).must_be_kind_of Hash
      a[1].delete("tags")

      resp = Server.new(DB_FILE).ingest(Nostrb.json(a))
      expect(resp).must_be_kind_of Array
      expect(resp.length).must_equal 1

      type, msg = *resp.first
      expect(type).must_equal "NOTICE"
      expect(msg).must_be_kind_of String
      expect(msg).wont_be_empty
    end

    # cut "id" in half
    it "handles field format errors with an error notice" do
      a = Nostrb::Source.publish(Test::SIGNED)
      expect(a[1]).must_be_kind_of Hash
      a[1]["id"] = a[1]["id"].slice(0, 32)

      resp = Server.new(DB_FILE).ingest(Nostrb.json(a))
      expect(resp).must_be_kind_of Array
      expect(resp.length).must_equal 1

      type, msg = *resp.first
      expect(type).must_equal "NOTICE"
      expect(msg).must_be_kind_of String
      expect(msg).wont_be_empty
    end

    # random "sig"
    it "handles invalid signature with OK:false" do
      a = Nostrb::Source.publish(Test::SIGNED)
      expect(a[1]).must_be_kind_of Hash
      a[1]["sig"] = SchnorrSig.bin2hex(Random.bytes(64))

      resp = Server.new(DB_FILE).ingest(Nostrb.json(a))
      expect(resp).must_be_kind_of Array
      expect(resp.length).must_equal 1

      type, id, value, msg = *resp.first
      expect(type).must_equal "OK"
      expect(id).must_equal a[1]["id"]
      expect(value).must_equal false
      expect(msg).must_be_kind_of String
      expect(msg).wont_be_empty
      expect(msg).must_match(/SignatureCheck/)
    end

    # "id" and "sig" spoofed from another event
    it "handles spoofed id with OK:false" do
      orig = Source.publish(Test.new_event('orig'))
      spoof = Source.publish(Test::SIGNED)

      orig[1]["id"] = spoof[1]["id"]
      orig[1]["sig"] = spoof[1]["sig"]

      # now sig and id agree with each other, but not orig's content/metadata
      # the signature should verify, but the id should not

      resp = Server.new(DB_FILE).ingest(Nostrb.json(orig))
      expect(resp).must_be_kind_of Array
      expect(resp.length).must_equal 1

      type, id, value, msg = *resp.first
      expect(type).must_equal "OK"
      expect(id).must_equal orig[1]["id"]
      expect(value).must_equal false
      expect(msg).must_be_kind_of String
      expect(msg).wont_be_empty
      expect(msg).must_match(/IdCheck/)
    end

    # random "id"
    it "handles invalid id with OK:false" do
      a = Source.publish(Test::SIGNED)
      a[1]["id"] = SchnorrSig.bin2hex(Random.bytes(32))

      resp = Server.new(DB_FILE).ingest(Nostrb.json(a))
      expect(resp).must_be_kind_of Array
      expect(resp.length).must_equal 1

      type, id, value, msg = *resp.first
      expect(type).must_equal "OK"
      expect(id).must_equal a[1]["id"]
      expect(value).must_equal false
      expect(msg).must_be_kind_of String
      expect(msg).wont_be_empty
    end
  end
end
