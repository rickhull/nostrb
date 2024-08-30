require 'nostrb/source'
require 'minitest/autorun'

include Nostr

describe Source do
  $sk, $pk, $hk = Nostr.keys

  describe "instantiation" do
    it "wraps a hex-formatted pubkey" do
      s = Source.new($hk)
      expect(s).must_be_kind_of Source
      expect(s.pubkey).must_equal $hk

      expect { Source.new($pk) }.must_raise EncodingError
    end
  end

  describe "event creation" do
    it "creates text_note events" do
      s = Source.new($hk)
      e = s.text_note('hello world')
      expect(e).must_be_kind_of Event
      expect(e.kind).must_equal 1
      expect(e.content).must_equal 'hello world'
    end

    it "creates set_metadata events" do
    end
  end
end
