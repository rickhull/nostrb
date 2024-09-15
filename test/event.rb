require 'nostrb/event'
require_relative 'common.rb'
require 'minitest/autorun'

include Nostr

describe Event do
  def text_note(content = '')
    Event.new(content, kind: 1, pk: Test::PK)
  end

  describe "class functions" do
    it "computes a 32 byte digest of a JSON serialization" do
      a = SignedEvent.serialize(Test::HASH)
      d = Event.digest(a)
      expect(d).must_be_kind_of String
      expect(d.length).must_equal 32
      expect(d.encoding).must_equal Encoding::BINARY
    end
  end

  describe "initialization" do
    it "wraps a string of content" do
      content = 'hello world'
      expect(text_note(content).content).must_equal content
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
  def signed_note(content = '')
    Event.new(content, kind: 1, pk: Test::PK).sign(Test::SK)
  end

  describe "class functions" do
    it "validates a JSON parsed hash" do
      h = SignedEvent.validate!(Test::HASH)
      expect(h).must_be_kind_of Hash
      %w[id pubkey kind content tags created_at sig].each { |k|
        expect(h.key?(k)).must_equal true
      }
    end

    it "verifies a JSON parsed hash" do
      h = SignedEvent.verify(Test::HASH)
      expect(h).must_be_kind_of Hash
    end

    it "serializes a JSON parsed hash" do
      a = SignedEvent.serialize(Test::HASH)
      expect(a).must_be_kind_of Array
      expect(a.length).must_equal 6
    end

    it "digests a hash JSON parsed hash, which it will serialize" do
      a = SignedEvent.serialize(Test::HASH)
      d = Event.digest(a)
      d2 = SignedEvent.digest(Test::HASH)
      expect(d2).must_equal d
    end
  end

  it "generates a timestamp at creation time" do
    expect(signed_note().created_at).must_be_kind_of Integer
  end

  it "signs the event, given a private key in binary format" do
    signed = signed_note()
    expect(signed).must_be_kind_of SignedEvent
    expect(signed.id).must_be_kind_of String
    expect(signed.created_at).must_be_kind_of Integer

    # check signature
    signature = signed.signature
    expect(signature).must_be_kind_of String
    expect(signature.encoding).must_equal Encoding::BINARY
    expect(signature.length).must_equal 64

    # check sig hex
    sig = signed.sig
    expect(sig).must_be_kind_of String
    expect(sig.encoding).wont_equal Encoding::BINARY
    expect(sig.length).must_equal 128
  end

  it "has a formalized Key-Value format" do
    h = signed_note().to_h
    expect(h).must_be_kind_of Hash
    expect(h.fetch "content").must_be_kind_of String
    expect(h.fetch "pubkey").must_be_kind_of String
    expect(h["pubkey"]).wont_be_empty
    expect(h.fetch "kind").must_be_kind_of Integer
    expect(h.fetch "tags").must_be_kind_of Array
    expect(h.fetch "created_at").must_be_kind_of Integer
    expect(h.fetch "id").must_be_kind_of String
    expect(h["id"]).wont_be_empty
    expect(h.fetch "sig").must_be_kind_of String
    expect(h["sig"]).wont_be_empty
  end

  it "has a formalized JSON format based on the object format" do
    j = signed_note().to_json
    expect(j).must_be_kind_of(String)
  end
end
