require 'nostrb/relay'
require 'minitest/autorun'

include Nostr

TYPES = ["EVENT", "OK", "EOSE", "CLOSED", "NOTICE"]

$sk, $pk = SchnorrSig.keypair

describe Server do
  def text_note(content = '')
    Event.new(content, pk: $pk).sign($sk)
  end

  def valid_response!(resp)
    expect(resp).must_be_kind_of Array
    expect(resp.length).must_be :>=, 2
    expect(resp.length).must_be :<=, 4
    resp[0..1].each { |s| expect(s).must_be_kind_of String }
    expect(resp[0].upcase).must_equal resp[0]
    expect(TYPES.include?(resp[0])).must_equal true
  end

  describe "class functions" do
    it "has an EVENT response, given subscriber_id and requested event" do
      event = text_note()
      sid = '1234'
      resp = Server.event(sid, event)
      valid_response!(resp)
      expect(resp[0]).must_equal "EVENT"
      expect(resp[1]).must_equal sid
      expect(resp[2]).must_be_kind_of Hash
      expect(resp[2]).wont_be_empty
    end

    it "has an OK response, given an event_id" do
      event = text_note()

      # positive ok
      resp = Server.ok(event.id)
      valid_response!(resp)
      expect(resp[0]).must_equal "OK"
      expect(resp[1]).must_equal event.id
      expect(resp[2]).must_equal true
      expect(resp[3]).must_be_kind_of String # empty by default

      # negative ok
      resp = Server.ok(event.id, "error: testing", ok: false)
      valid_response!(resp)
      expect(resp[0]).must_equal "OK"
      expect(resp[1]).must_equal event.id
      expect(resp[2]).must_equal false
      expect(resp[3]).must_be_kind_of String
      expect(resp[3]).wont_be_empty

      # ok:false requires nonempty message
      expect { Server.ok(event.id, "", ok: false) }.must_raise FormatError
      expect { Server.ok(event.id, ok: false) }.must_raise FormatError
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

      e = Nostr::Error.new("things")
      expect(e).must_be_kind_of Exception
      expect(Server.message(e)).must_equal "Nostr::Error: things"
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
  end

  it "has a single response to EVENT requests" do
    # respond error / NOTICE
    # respond OK: false
    # respond OK: true
  end

  it "has multiple responses to REQ requets" do
    # respond EVENT
    # respond EVENT
    # ...
    # respond EOSE
  end

  it "has a single response to CLOSE requests" do
    # respond CLOSED
  end
end
