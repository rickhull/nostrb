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

    it "creates set_metadata events" do
      s = Source.new($pk)
      e = s.set_metadata(name: 'Bob Loblaw',
                         about: "Bob Loblaw's Law Blog",
                         picture: "https://localhost/me.jpg")
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 0

      # above data becomes JSON string in content
      expect(e.content).wont_be_empty
      expect(e.tags).must_be_empty
    end

    it "creates contact_list events" do
      pubkey_hsh = {
        SchnorrSig.bin2hex(Random.bytes(32)) => ['foo', 'bar'],
        SchnorrSig.bin2hex(Random.bytes(32)) => ['baz', 'quux'],
        SchnorrSig.bin2hex(Random.bytes(32)) => ['asdf', '123'],
      }
      s = Source.new($pk)
      e = s.contact_list(pubkey_hsh)
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 3

      # above data goes into tags structure, not content
      expect(e.content).must_be_empty
      expect(e.tags).wont_be_empty
    end
  end
end
