require 'nostrb'
require 'minitest/autorun'

SS = SchnorrSig

describe Nostr do
  describe "module functions" do
    it "parses a JSON string to a Ruby object" do
      expect(Nostr.parse('{}')).must_equal Hash.new
      expect(Nostr.parse('[]')).must_equal Array.new
    end

    it "generates JSON from a Ruby hash or array" do
      expect(Nostr.json({})).must_equal '{}'
      expect(Nostr.json([])).must_equal '[]'
    end

    it "validates string class and length" do
      str = 'asdf'

      expect(Nostr.string!(str)).must_equal str
      expect { Nostr.string!(1234) }.must_raise SS::TypeError
    end

    it "validates a binary string" do
      binary = "\x00\x01\x02".b

      expect(Nostr.binary!(binary)).must_equal binary
      expect(Nostr.binary!(binary, 3)).must_equal binary
      expect { Nostr.binary!("010203") }.must_raise SS::EncodingError
      expect { Nostr.binary!("\x00\x01\x02") }.must_raise SS::EncodingError
    end

    it "validates a hex string" do
      hex = "0123456789abcdef"

      expect(Nostr.hex!(hex)).must_equal hex
      expect(Nostr.hex!(hex, 16)).must_equal hex
      expect { Nostr.hex!(hex, 8) }.must_raise SS::SizeError
      expect { Nostr.hex!("0123".b) }.must_raise SS::EncodingError
    end
  end
end
