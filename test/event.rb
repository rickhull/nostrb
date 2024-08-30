require 'nostrb/event'
require 'minitest/autorun'

include Nostr

$secret_key, $pubkey = Nostr.keypair

def text_note(content = '')
  Event.new(content, kind: 1, pubkey: $pubkey)
end

$json = text_note().sign($secret_key).to_json

describe Event do
  describe "class functions" do
    it "validates a JSON string and returns a ruby hash" do
      h = Event.hash($json)
      expect(h).must_be_kind_of Hash
      [:id, :pubkey, :kind, :content, :tags, :created_at, :sig].each { |sym|
        expect(h.key?(sym)).must_equal true
      }

      expect { Event.hash('hello world') }.must_raise JSON::ParserError
      expect { Event.hash('{}') }.must_raise KeyError
    end

    it "serializes a Ruby hash to a JSON array" do
      h = Event.hash($json)
      s = Event.serialize(h)
      p = JSON.parse(s)
      expect(p).must_be_kind_of Array
      expect(p.length).must_equal 6
    end

    it "verifies the signature and validates the id of a JSON event string" do
      h = Event.verify($json)
      expect(h).must_be_kind_of Hash
    end
  end

  it "wraps a string of content" do
    content = 'hello world'
    expect(text_note(content).content).must_equal content
  end

  it "requires a _kind_ integer, defaulting to 1" do
    expect(Event.new(kind: 0, pubkey: $pubkey).kind).must_equal 0
    expect(Event.new(pubkey: $pubkey).kind).must_equal 1
  end

  it "requires a pubkey in hex format" do
    expect(text_note().pubkey).must_equal $pubkey
    expect {
      Event.new(kind: 1, pubkey: SchnorrSig.hex2bin($pubkey))
    }.must_raise EncodingError
    expect {
      Event.new(kind: 1, pubkey: "0123456789abcdef")
    }.must_raise SizeError
    expect { Event.new }.must_raise
  end

  it "generates a timestamp at creation time" do
    expect(text_note().created_at).must_be_kind_of Integer
  end

  it "has empty id and signature at creation time" do
    expect(text_note().id).must_be_empty
    expect(text_note().signature).must_be_empty
  end

  it "can create a digest, but not an id, before signing time" do
    e = text_note()
    d = e.digest

    # the digest represents what the id would be at signing time
    # but this value will change when the timestamp is set, at signing time
    # so this value is not useful before signing time as it will change
    expect(d).must_be_kind_of String
    expect(d.length).must_equal 32
    expect(d.encoding).must_equal Encoding::BINARY

    # the id is not available until the event is signed
    expect(e.id).must_be_empty

    # now sign the message to have a permanently valid id
    e.sign($secret_key)
    i = e.id
    expect(i).must_be_kind_of String
    expect(i.length).must_equal 64
    expect(i.encoding).wont_equal Encoding::BINARY
  end

  it "signs the event, given a private key in hex format" do
    e = text_note().sign($secret_key)
    signature = e.signature

    # check signature
    expect(signature).must_be_kind_of String
    expect(signature.encoding).must_equal Encoding::BINARY
    expect(signature.length).must_equal 64

    # check signed event
    expect(e.created_at).wont_be_nil

    # check sig hex
    sig = e.sig
    expect(sig).must_be_kind_of String
    expect(sig.encoding).wont_equal Encoding::BINARY
    expect(sig.length).must_equal 128

    # sign it again, get a new signature
    sign2 = e.sign($secret_key)
    expect(sign2).wont_equal signature

    # negative testing
    expect { e.sign('a' * 32) }.must_raise SizeError
    expect { e.sign('a'.b * 32) }.must_raise EncodingError
  end

  it "has a formalized Key-Value format" do
    e = text_note()
    h = e.to_h
    expect(h).must_be_kind_of Hash
    expect(h.fetch :id).must_be_kind_of String
    expect(h.fetch :id).must_be_empty
    expect(h.fetch :pubkey).must_be_kind_of String
    expect(h.fetch :created_at).must_be_kind_of Integer
    expect(h.fetch :kind).must_be_kind_of Integer
    expect(h.fetch :content).must_be_kind_of String
    expect(h.fetch :sig).must_be_kind_of String
    expect(h.fetch :sig).must_be_empty

    e.sign($secret_key)
    h = e.to_h
    expect(h).must_be_kind_of Hash
    expect(h.fetch :id).must_be_kind_of String
    expect(h.fetch :id).wont_be_empty
    expect(h.fetch :pubkey).must_be_kind_of String
    expect(h.fetch :created_at).must_be_kind_of Integer
    expect(h.fetch :kind).must_be_kind_of Integer
    expect(h.fetch :content).must_be_kind_of String
    expect(h.fetch :sig).must_be_kind_of String
    expect(h.fetch :sig).wont_be_empty
  end

  it "has a formalized JSON format based on the object format" do
    e = text_note()
    j = e.to_json
    expect(j).must_be_kind_of(String)

    e.sign($secret_key)
    js = e.to_json
    expect(js.length).must_be :>, j.length
  end

  describe "event tags" do
    it "supports tags in the form of Array[Array[String]]" do
      e = text_note()
      expect(e.tags).must_be_kind_of Array
      expect(e.tags).must_be_empty

      e.add_tag('tag', 'value')
      expect(e.tags).wont_be_empty
      expect(e.tags.length).must_equal 1

      tags0 = e.tags[0]
      expect(tags0.length).must_equal 2
      expect(tags0[0]).must_equal 'tag'
      expect(tags0[1]).must_equal 'value'

      e.add_tag('foo', 'bar', 'baz')
      expect(e.tags.length).must_equal 2

      tags1 = e.tags[1]
      expect(tags1.length).must_equal 3
      expect(tags1[2]).must_equal 'baz'
    end

    it "references prior events" do
      p = text_note()
      p.sign($secret_key)
      e = text_note()
      e.ref_event(p.id)
      expect(e.tags).wont_be_empty
      expect(e.tags.length).must_equal 1
      expect(e.tags[0][0]).must_equal 'e'
      expect(e.tags[0][1]).must_equal p.id
    end

    it "references known public keys" do
      e = text_note()
      _, pubkey = Nostr.keypair
      e.ref_pubkey(pubkey)
      expect(e.tags).wont_be_empty
      expect(e.tags.length).must_equal 1
      expect(e.tags[0][0]).must_equal 'p'
      expect(e.tags[0][1]).must_equal pubkey
    end
  end
end
