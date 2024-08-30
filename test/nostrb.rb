require 'nostrb'
require 'minitest/autorun'

describe Nostr do
  describe "module functions" do
    describe "keygen" do
      it "can generate a secret key" do
        sk, pk, hk = Nostr.gen_keys
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
        sk, pk, hk = Nostr.gen_keys(rk)
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
      it "enforces String class where expected" do
        str = 'asdf'
        expect(Nostr.string!(str)).must_equal str
        expect { Nostr.string!(1234) }.must_raise TypeError
      end

      it "enforces Integer class where expected" do
        int = 1234
        expect(Nostr.integer!(int)).must_equal int
        expect { Nostr.integer!('1234') }.must_raise TypeError
      end

      it "enforces Array class where expected" do
        ary = [1,2,3]
        expect(Nostr.array!(ary)).must_equal ary
        expect { Nostr.array!(Hash.new) }.must_raise TypeError
      end

      it "enforces a particular tag structure where expected" do
        # Array[Array[String]]
        tags = [['a', 'b', 'c'], ['1', '2', '3', '4']]
        expect(Nostr.tags!(tags)).must_equal tags

        bads = [
          ['a', 'b', 'c', '1' , '2', '3', '4'],  # Array[String]
          [['a', 'b', 'c'], [1, 2, 3, 4]],       # Array[Array[String|Integer]]
          ['a', 'b', 'c', ['1' , '2', '3', '4']],# Array[Array | String]
          'a',                                   # String
          [[:a, :b, :c], [1, 2, 3, 4]],          # Array[Array[Symbol|String]]
        ]
        bads.each { |val|
          expect { Nostr.tags!(val) }.must_raise TypeError
        }
      end

      it "validates a binary string" do
        binary = "\x00\x01\x02".b

        expect(Nostr.binary!(binary)).must_equal binary
        expect(Nostr.binary!(binary, 3)).must_equal binary
        expect { Nostr.binary!("010203") }.must_raise EncodingError
        expect { Nostr.binary!("\x00\x01\x02") }.must_raise EncodingError
      end

      it "validates a hex string" do
        hex = "0123456789abcdef"

        expect(Nostr.hex!(hex)).must_equal hex
        expect(Nostr.hex!(hex, 16)).must_equal hex
        expect { Nostr.hex!(hex, 8) }.must_raise Nostr::SizeError
        expect { Nostr.hex!("0123".b) }.must_raise EncodingError
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
