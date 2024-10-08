require 'nostrb/event'
require_relative 'common.rb'
require 'minitest/autorun'

include Nostrb

describe Event do
  def text_note(content = '')
    Event.new(content, kind: 1, pk: Test::PK)
  end

  describe "class functions" do
    it "computes a 32 byte digest of a JSON serialization" do
      d = Event.digest(Test::EVENT.to_a)
      expect(d).must_be_kind_of String
      expect(d.length).must_equal 32
      expect(d.encoding).must_equal Encoding::BINARY
    end
  end

  describe "initialization" do
    it "wraps a string of content" do
      content = 'hello world'
      e = Event.new(content, pk: Test::PK)
      expect(e).must_be_kind_of Event
      expect(e.content).must_equal content
    end

    it "requires a _kind_ integer, defaulting to 1" do
      expect(Event.new(kind: 0, pk: Test::PK).kind).must_equal 0
      expect(Event.new(pk: Test::PK).kind).must_equal 1
    end

    it "requires a public key in binary format" do
      expect(Test::EVENT.pk).must_equal Test::PK
      expect {
        Event.new(kind: 1, pk: SchnorrSig.bin2hex(Test::PK))
      }.must_raise EncodingError
      expect {
        Event.new(kind: 1, pk: "0123456789abcdef".b)
      }.must_raise SizeError
      expect { Event.new }.must_raise
    end
  end

  it "provides its content in a string context" do
    s = text_note('hello').to_s
    expect(s).must_equal 'hello'
  end

  it "serializes to an array starting with 0, length 6" do
    a = text_note('hello').to_a
    expect(a).must_be_kind_of Array
    expect(a[0]).must_equal 0
    expect(a.length).must_equal 6
    expect(a[5]).must_equal 'hello'
  end

  it "has a pubkey in hex format" do
    pubkey = Test::EVENT.pubkey
    expect(pubkey).must_be_kind_of String
    expect(pubkey.length).must_equal 64
  end

  it "requires a timestamp to create a SHA256 digest" do
    e = Test::EVENT
    d = e.digest(Time.now.to_i)
    expect(d).must_be_kind_of String
    expect(d.length).must_equal 32
    expect(d.encoding).must_equal Encoding::BINARY
  end

  it "provides a SignedEvent when signed with a secret key" do
    expect(Test::EVENT.sign(Test::SK)).must_be_kind_of SignedEvent
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
      s = p.sign(Test::SK)

      e = text_note()
      e.ref_event(s.id)
      expect(e.tags).wont_be_empty
      expect(e.tags.length).must_equal 1
      expect(e.tags[0][0]).must_equal 'e'
      expect(e.tags[0][1]).must_equal s.id
    end

    it "references known public keys" do
      e = text_note()
      pubkey = SchnorrSig.bin2hex Test::PK
      e.ref_pubkey(pubkey)
      expect(e.tags).wont_be_empty
      expect(e.tags.length).must_equal 1
      expect(e.tags[0][0]).must_equal 'p'
      expect(e.tags[0][1]).must_equal pubkey
    end
  end
end

describe SignedEvent do
  describe "class functions" do
    it "ingests a JSON parsed hash" do
      edata = SignedEvent.ingest(Test::STATIC_HASH)
      expect(edata).must_be_kind_of SignedEvent
      %w[id pubkey kind content tags created_at sig].each { |k|
        expect(edata.send(k)).wont_be_nil
      }
    end

    it "verifies the id and sig of a JSON parsed hash" do
      edata = SignedEvent.ingest(Test::STATIC_HASH)
      expect(edata.valid_id?).must_equal true
      expect(edata.valid_sig?).must_equal true
    end

    it "serializes a JSON parsed hash" do
      edata = SignedEvent.ingest(Test::STATIC_HASH)
      a = edata.serialize
      expect(a).must_be_kind_of Array
      expect(a.length).must_equal 6
    end

    # TODO: reconsider?  this got carried along some refactors
    it "digests a hash JSON parsed hash, which it will serialize" do
      edata = SignedEvent.ingest(Test::STATIC_HASH)
      a = edata.serialize
      d = Event.digest(a)

      expect(d).must_equal SchnorrSig.hex2bin(edata.id)
    end
  end

  it "generates a timestamp at creation time" do
    expect(Test.new_event().created_at).must_be_kind_of Integer
  end

  it "signs the event, given a private key in binary format" do
    signed = Test.new_event()
    expect(signed).must_be_kind_of SignedEvent
    expect(signed.id).must_be_kind_of String
    expect(signed.created_at).must_be_kind_of Integer

    # check sig hex
    sig = signed.sig
    expect(sig).must_be_kind_of String
    expect(sig.encoding).wont_equal Encoding::BINARY
    expect(sig.length).must_equal 128
  end

  it "has a formalized Data format" do
    data = Test.new_event()
    expect(data).must_be_kind_of SignedEvent
    expect(data.content).must_be_kind_of String
    expect(data.pubkey).must_be_kind_of String
    expect(data.pubkey).wont_be_empty
    expect(data.kind).must_be_kind_of Integer
    expect(data.tags).must_be_kind_of Array
    expect(data.created_at).must_be_kind_of Integer
    expect(data.id).must_be_kind_of String
    expect(data.id).wont_be_empty
    expect(data.sig).must_be_kind_of String
    expect(data.sig).wont_be_empty
  end
end
