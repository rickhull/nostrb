require 'nostrb/source'
require_relative 'common'
require 'minitest/autorun'

include Nostrb

describe Source do
  describe "instantiation" do
    it "wraps a binary pubkey" do
      s = Source.new(Test::PK)
      expect(s).must_be_kind_of Source
      expect(s.pk).must_equal Test::PK

      expect {
        Source.new(SchnorrSig.bin2hex(Test::PK))
      }.must_raise EncodingError
    end
  end

  describe "event creation" do
    it "creates text_note events" do
      s = Source.new(Test::PK)
      e = s.text_note('hello world')
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 1
      expect(e.content).must_equal 'hello world'
    end

    it "creates user_metadata events" do
      s = Source.new(Test::PK)
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
        Nostrb.random_hex(32) => { relay: 'foo', petname: 'bar' },
        Nostrb.random_hex(32) => { relay: 'baz', petname: 'quux' },
        Nostrb.random_hex(32) => { relay: 'asdf', petname: '123' },
      }
      s = Source.new(Test::PK)
      e = s.follow_list(pubkey_hsh)
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 3

      # above data goes into tags structure, not content
      expect(e.content).must_be_empty
      expect(e.tags).wont_be_empty
    end

    it "creates deletion_request events" do
      fake_ids = Array.new(3) { Nostrb.random_hex(32) }

      s = Source.new(Test::PK)
      e = s.deletion_request('testing deletes', *fake_ids)
      expect(e.content).wont_be_empty
      expect(e.tags).wont_be_empty
    end
  end
end

describe Filter do
  it "starts with a _since_ value" do
    f = Filter.new
    expect(f).must_be_kind_of Filter
    expect(f.to_h).wont_be_empty
    expect(f.since).wont_be_nil
    expect(f.since).must_be_kind_of Integer
  end

  it "validates added ids" do
    f = Filter.new
    ids = Array.new(3) { Nostrb.random_hex(32) }
    f.add_ids(*ids)
    expect(f.to_h).wont_be_empty
    expect(f.to_h["ids"]).wont_be_empty
    expect(f.to_h["ids"]).must_equal ids
  end

  it "validates added tags" do
    f = Filter.new
    ids = Array.new(3) { Nostrb.random_hex(32) }
    f.add_tag('e', ids)
    hsh = f.to_h
    expect(hsh).wont_be_empty
    expect(hsh.key?("tags")).must_equal false
    expect(hsh["#e"]).wont_be_empty
    expect(hsh["#e"]).must_equal ids
  end

  it "accepts integers for since, until, and limit" do
    f = Filter.new(limit: 99)
    f.since = Time.now.to_i - 99_999
    f.until = Time.now.to_i
    hsh = f.to_h
    expect(hsh).wont_be_empty
    expect(hsh["until"]).must_be_kind_of Integer
    expect(hsh["since"]).must_be_kind_of Integer
    expect(hsh["limit"]).must_equal 99
  end
end

describe "stuff" do
  it "creates EVENT messages to publish signed events" do
    sk, pk = SchnorrSig.keypair
    e = Event.new(pk: pk).sign(sk)
    a = Source.publish(e)
    expect(a).must_be_kind_of Array
    expect(a[0]).must_equal "EVENT"
  end

  it "creates REQ messages to subscribe to events using filters" do
    f = Filter.new
    pubkey = Nostrb.random_hex(32)
    sid = Source.random_sid
    f.add_authors(pubkey)
    a = Source.subscribe(sid, f)
    expect(a).must_be_kind_of Array
    expect(a[0]).must_equal "REQ"
  end

  it "creates CLOSE messages to end all subscriptions / streams" do
    sid = Source.random_sid
    a = Source.close(sid)
    expect(a).must_be_kind_of Array
    expect(a[0]).must_equal "CLOSE"
  end
end
