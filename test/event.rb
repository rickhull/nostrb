require 'nostrb/event'
require 'minitest/autorun'

include Nostr

describe Event do
  SK, PK = SchnorrSig.keypair
  HK = SchnorrSig.bin2hex(PK)
  EVENT = Event.new(kind: 1, pubkey: HK)

  describe "class functions" do
    it "creates a _set_metadata_ event" do
      e = Event.set_metadata(name: 'Rick', pubkey: HK)
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 0
    end

    it "creates a _text_note_ event" do
      e = Event.text_note('hello world', pubkey: HK)
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 1
    end

    it "creates a _contact_list_ event" do
      list = {
        "deadbeef" * 8 => ["wss://deadbeef.relay", "deadbeef"],
        "cafebabe" * 8 => ["wss://cafebabe.relay", "cafebabe"],
      }
      e = Event.contact_list(list, pubkey: HK)
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 3
    end
  end

  it "wraps a string of content" do
    content = 'hello world'

    e = Event.new(content, kind: 1, pubkey: HK)
    expect(e.content).must_equal content
  end

  it "requires a _kind_ integer" do
    expect(EVENT.kind).must_equal 1
    expect(Event.new(kind: 0, pubkey: HK).kind).must_equal 0
    expect { Event.new(pubkey: HK) }.must_raise ArgumentError
  end

  it "requires a pubkey in hex format" do
    expect(EVENT.pubkey).must_equal HK
    expect { Event.new(kind: 1, pubkey: PK) }.must_raise Nostr::SizeError
    expect {
      Event.new(kind: 1, pubkey: PK + PK)
    }.must_raise Nostr::EncodingError
  end

  it "has no timestamp or signature at creation time" do
    expect(EVENT.created_at).must_be_nil
    expect(EVENT.signature).must_be_nil
  end

  it "creates a digest and hex id, on demand" do
    e = Event.new(kind: 1, pubkey: HK)
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
    e = Event.new(kind: 1, pubkey: HK)
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
    e = Event.new(kind: 1, pubkey: HK)
    signature = e.sign(SK)

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
    sign2 = e.sign(SK)
    expect(sign2).wont_equal signature

    # negative testing
    expect { e.sign('a' * 31) }.must_raise Nostr::SizeError
    expect { e.sign('a' * 32) }.must_raise Nostr::EncodingError
  end

  it "has a formalized object format" do
    e = Event.new(kind: 1, pubkey: HK)
    o = e.object
    expect(o).must_be_kind_of Hash
    expect(o.fetch :id).must_be_kind_of String
    expect(o.fetch :pubkey).must_be_kind_of String
    expect(o.fetch :created_at).must_be_kind_of Integer
    expect(o.fetch :kind).must_be_kind_of Integer
    expect(o.fetch :content).must_be_kind_of String
    expect(o.fetch :sig).must_be_nil

    e.sign(SK)
    o = e.object
    expect(o).must_be_kind_of Hash
    expect(o.fetch :id).must_be_kind_of String
    expect(o.fetch :pubkey).must_be_kind_of String
    expect(o.fetch :created_at).must_be_kind_of Integer
    expect(o.fetch :kind).must_be_kind_of Integer
    expect(o.fetch :content).must_be_kind_of String
    expect(o.fetch :sig).must_be_kind_of String
  end

  it "has a formalized JSON format based on the object format" do
    e = Event.new(kind: 1, pubkey: HK)
    j = e.json
    expect(j).must_be_kind_of(String)

    e.sign(SK)
    js = e.json
    expect(js.length).must_be :>, j.length
  end

  # TODO: tag stuff
end
