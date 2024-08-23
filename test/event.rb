require 'nostrb/event'
require 'minitest/autorun'

include Nostr

$sk, $pk = SchnorrSig.keypair
$hk = SchnorrSig.bin2hex($pk)

def text_note(content = '')
  Event.new(content, kind: 1, pubkey: $hk)
end

$json = text_note().sign($sk).to_json

describe Event do
  describe "class functions" do
    it "validates a JSON string and returns a ruby hash" do
      h = Event.hash($json)
      expect(h).must_be_kind_of Hash
      [:id, :pubkey, :kind, :content, :tags, :created_at, :sig].each { |sym|
        expect(h.key?(sym)).must_equal true
      }

      expect { Event.hash('hello world') }.must_raise JSON::ParserError
      expect { Event.hash('{"id": "1234"}') }.must_raise KeyError
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
    expect(Event.new(kind: 0, pubkey: $hk).kind).must_equal 0
    expect(Event.new(pubkey: $hk).kind).must_equal 1
  end

  it "requires a pubkey in hex format" do
    expect(text_note().pubkey).must_equal $hk
    expect {
      Event.new(kind: 1, pubkey: $pk)
    }.must_raise SchnorrSig::EncodingError
    expect {
      Event.new(kind: 1, pubkey: "0123456789abcdef")
    }.must_raise SchnorrSig::SizeError
    expect { Event.new }.must_raise
  end

  it "has no timestamp or signature at creation time" do
    expect(text_note().created_at).must_be_nil
    expect(text_note().signature).must_be_nil
  end

  it "creates a digest and hex id, on demand" do
    e = text_note()
    d = e.digest
    expect(d).must_be_kind_of String
    expect(d.length).must_equal 32
    expect(d.encoding).must_equal Encoding::BINARY

    # the id is now the hex encoding of the digest
    i = e.id
    expect(i).must_be_kind_of String
    expect(i.length).must_equal 64
    expect(i.encoding).wont_equal Encoding::BINARY

    ### New Event ###

    # the id is created automatically
    e = text_note()
    i = e.id
    expect(i).must_be_kind_of String
    expect(i.length).must_equal 64
    expect(i.encoding).wont_equal Encoding::BINARY

    # the digest has already been created
    d = e.digest
    expect(d).must_be_kind_of String
    expect(d.length).must_equal 32
    expect(d.encoding).must_equal Encoding::BINARY
  end

  it "signs the event, given a binary private key" do
    e = text_note().sign($sk)
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
    sign2 = e.sign($sk)
    expect(sign2).wont_equal signature

    # negative testing
    expect { e.sign('a'.b * 31) }.must_raise SchnorrSig::SizeError
    expect { e.sign('a' * 32) }.must_raise SchnorrSig::EncodingError
  end

  it "has a formalized Key-Value format" do
    e = text_note()
    h = e.to_h
    expect(h).must_be_kind_of Hash
    expect(h.fetch :id).must_be_kind_of String
    expect(h.fetch :pubkey).must_be_kind_of String
    expect(h.fetch :created_at).must_be_kind_of Integer
    expect(h.fetch :kind).must_be_kind_of Integer
    expect(h.fetch :content).must_be_kind_of String
    expect(h.fetch :sig).must_be_empty

    e.sign($sk)
    h = e.to_h
    expect(h).must_be_kind_of Hash
    expect(h.fetch :id).must_be_kind_of String
    expect(h.fetch :pubkey).must_be_kind_of String
    expect(h.fetch :created_at).must_be_kind_of Integer
    expect(h.fetch :kind).must_be_kind_of Integer
    expect(h.fetch :content).must_be_kind_of String
    expect(h.fetch :sig).must_be_kind_of String
  end

  it "has a formalized JSON format based on the object format" do
    e = text_note()
    j = e.to_json
    expect(j).must_be_kind_of(String)

    e.sign($sk)
    js = e.to_json
    expect(js.length).must_be :>, j.length
  end

  # TODO: tag stuff
end
