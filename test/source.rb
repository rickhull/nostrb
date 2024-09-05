require 'nostrb/source'
require 'minitest/autorun'

include Nostr

describe Source do
  $sk, $pk = SchnorrSig.keypair

  describe "instantiation" do
    it "wraps a binary pubkey" do
      s = Source.new($pk)
      expect(s).must_be_kind_of Source
      expect(s.pk).must_equal $pk

      expect {
        Source.new(SchnorrSig.bin2hex($pk))
      }.must_raise EncodingError
    end
  end

  describe "event creation" do
    it "creates text_note events" do
      s = Source.new($pk)
      e = s.text_note('hello world')
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 1
      expect(e.content).must_equal 'hello world'
    end

    it "creates user_metadata events" do
      s = Source.new($pk)
      e = s.user_metadata(name: 'Bob Loblaw',
                          about: "Bob Loblaw's Law Blog",
                          picture: "https://localhost/me.jpg")
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 0

      # above data becomes JSON string in content
      expect(e.content).wont_be_empty
      expect(e.tags).must_be_empty
    end

    it "creates follow_list events" do
      pubkey_hsh = {
        SchnorrSig.bin2hex(Random.bytes(32)) => ['foo', 'bar'],
        SchnorrSig.bin2hex(Random.bytes(32)) => ['baz', 'quux'],
        SchnorrSig.bin2hex(Random.bytes(32)) => ['asdf', '123'],
      }
      s = Source.new($pk)
      e = s.follow_list(pubkey_hsh)
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 3

      # above data goes into tags structure, not content
      expect(e.content).must_be_empty
      expect(e.tags).wont_be_empty
    end

    it "creates deletion_request events" do
      # TODO
    end
  end
end

describe Filter do
  it "starts empty" do
    f = Filter.new
    expect(f).must_be_kind_of Filter
    expect(f.to_h).must_be_empty
  end

  it "validates added ids" do
    f = Filter.new
    ids = Array.new(3) { SchnorrSig.bin2hex(Random.bytes(32)) }
    f.add_ids(*ids)
    expect(f.to_h).wont_be_empty
    expect(f.to_h["ids"]).wont_be_empty
    expect(f.to_h["ids"]).must_equal ids
  end

  it "validates added tags" do
    f = Filter.new
    ids = Array.new(3) { SchnorrSig.bin2hex(Random.bytes(32)) }
    f.add_tag('e', ids)
    hsh = f.to_h
    expect(hsh).wont_be_empty
    expect(hsh.key?("tags")).must_equal false
    expect(hsh["#e"]).wont_be_empty
    expect(hsh["#e"]).must_equal ids
  end

  it "accepts integers for since, until, and limit" do
    f = Filter.new
    f.since = Time.now.to_i - 99_999
    f.until = Time.now.to_i
    hsh = f.to_h
    expect(hsh).wont_be_empty
    expect(hsh["until"]).must_be_kind_of Integer
    expect(hsh["since"]).must_be_kind_of Integer
    expect(hsh.key?("limit")).must_equal false

    f.limit = 99
    expect(f.to_h["limit"]).must_equal 99
  end
end

describe Operator do
  it "initializes with a subscription_id" do
    sid = SchnorrSig.bin2hex Random.bytes(32)
    o = Operator.new(sid)
    expect(o).must_be_kind_of Operator
  end

  it "creates EVENT messages to publish signed events" do
    sk, pk = SchnorrSig.keypair
    e = Event.new(pk: pk).sign(sk)
    o = Operator.generate
    m = o.publish(e)
    expect(m).must_be_kind_of String
    a = Nostr.parse(m)
    expect(a).must_be_kind_of Array
    expect(a[0]).must_equal "EVENT"
  end

  it "creates REQ messages to subscribe to events using filters" do
    f = Filter.new
    pubkey = SchnorrSig.bin2hex Random.bytes(32)
    f.add_authors(pubkey)
    o = Operator.generate
    m = o.subscribe(f)
    expect(m).must_be_kind_of String
    a = Nostr.parse(m)
    expect(a).must_be_kind_of Array
    expect(a[0]).must_equal "REQ"
  end

  it "creates CLOSE messages to end all subscriptions / streams" do
    m = Operator.generate.close
    expect(m).must_be_kind_of String
    a = Nostr.parse(m)
    expect(a).must_be_kind_of Array
    expect(a[0]).must_equal "CLOSE"
  end
end
