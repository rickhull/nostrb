require 'nostrb'
require 'minitest/autorun'

describe Nostr do
  describe "module functions" do
    describe "keygen" do
      it "can generate a secret key" do
        sk, pk, hk = Nostr.keys
        [sk, pk].each { |binary|
          expect(binary).must_be_kind_of String
          expect(binary.encoding).must_equal Encoding::BINARY
          expect(binary.length).must_equal 32
        }
        expect(hk).must_be_kind_of String
        expect(hk.encoding).wont_equal Encoding::BINARY
        expect(hk.length).must_equal 64
      end

      it "can generate a public key given a secret key" do
        rk = Random.bytes(32)
        sk, pk, hk = Nostr.keys(rk)
        expect(sk).must_equal rk
        [sk, pk].each { |binary|
          expect(binary).must_be_kind_of String
          expect(binary.encoding).must_equal Encoding::BINARY
          expect(binary.length).must_equal 32
        }
        expect(hk).must_be_kind_of String
        expect(hk.encoding).wont_equal Encoding::BINARY
        expect(hk.length).must_equal 64
      end
    end

    describe "type enforcement" do
      it "can check any class" do
        str = 'asdf'
        expect(Nostr.check!(str, String)).must_equal str
        expect { Nostr.check!(str, Range) }.must_raise TypeError

        range = (0..10)
        expect(Nostr.check!(range, Range)).must_equal range
        expect { Nostr.check!(range, Symbol) }.must_raise TypeError

        sym = :symbol
        expect(Nostr.check!(sym, Symbol)).must_equal sym
        expect { Nostr.check!(sym, String) }.must_raise TypeError
      end

      it "enforces String class where expected" do
        str = 'asdf'
        expect(Nostr.string!(str)).must_equal str
        expect { Nostr.string!(1234) }.must_raise TypeError
      end

      it "validates a binary string" do
        binary = "\x00\x01\x02".b

        expect(Nostr.binary!(binary)).must_equal binary
        expect(Nostr.binary!(binary, 3)).must_equal binary
        expect { Nostr.binary!(binary, 4) }.must_raise Nostr::SizeError
        expect { Nostr.binary!("010203") }.must_raise EncodingError
        expect { Nostr.binary!("\x00\x01\x02") }.must_raise EncodingError
      end

      it "validates a hex string" do
        hex = "0123456789abcdef"

        expect(Nostr.text!(hex)).must_equal hex
        expect(Nostr.text!(hex, 16)).must_equal hex
        expect { Nostr.text!(hex, 8) }.must_raise Nostr::SizeError
        expect { Nostr.text!("0123".b) }.must_raise EncodingError
      end

      it "enforces Integer class where expected" do
        int = 1234
        expect(Nostr.integer!(int)).must_equal int
        expect { Nostr.integer!('1234') }.must_raise TypeError
      end

      it "enforces a particular tag structure where expected" do
        # Array[Array[String]]
        tags = [['a', 'b', 'c'], ['1', '2', '3', '4']]
        expect(Nostr.tags!(tags)).must_equal tags

        [
          ['a', 'b', 'c', '1' , '2', '3', '4'],  # Array[String]
          [['a', 'b', 'c'], [1, 2, 3, 4]],       # Array[Array[String|Integer]]
          ['a', 'b', 'c', ['1' , '2', '3', '4']],# Array[Array | String]
          'a',                                   # String
          [[:a, :b, :c], [1, 2, 3, 4]],          # Array[Array[Symbol|String]]
        ].each { |bad|
          expect { Nostr.tags!(bad) }.must_raise TypeError
        }
      end
    end

    describe "JSON I/O" do
      it "parses a JSON string to a Ruby object" do
        expect(Nostr.parse('{}')).must_equal Hash.new
        expect(Nostr.parse('[]')).must_equal Array.new
      end

      it "generates JSON from a Ruby hash or array" do
        expect(Nostr.json({})).must_equal '{}'
        expect(Nostr.json([])).must_equal '[]'
      end
    end
  end
end
