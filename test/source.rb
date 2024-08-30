require 'nostrb/source'
require 'minitest/autorun'

### TODO elsewhere: add binary: false for content strings


include Nostr

describe Source do
  $skey, $pubkey = Nostr.keypair

  describe "instantiation" do
    it "wraps a hex-formatted pubkey" do
      s = Source.new($pubkey)
      expect(s).must_be_kind_of Source
      expect(s.pubkey).must_equal $pubkey

      expect {
        Source.new(SchnorrSig.hex2bin($pubkey))
      }.must_raise EncodingError
    end
  end

  describe "event creation" do
    it "creates text_note events" do
      s = Source.new($pubkey)
      e = s.text_note('hello world')
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 1
      expect(e.content).must_equal 'hello world'
    end

    it "creates set_metadata events" do
      s = Source.new($pubkey)
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
      s = Source.new($pubkey)
      e = s.contact_list(pubkey_hsh)
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 3

      # above data goes into tags structure, not content
      expect(e.content).must_be_empty
      expect(e.tags).wont_be_empty
    end
  end
end
