require 'nostrb'
require 'minitest/autorun'

describe Nostr do
  describe "module functions" do
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

      it "validates a text (possibly hex) string" do
        hex = "0123456789abcdef"

        expect(Nostr.txt!(hex)).must_equal hex
        expect(Nostr.txt!(hex, length: 16)).must_equal hex
        expect { Nostr.txt!(hex, length: 8) }.must_raise Nostr::SizeError
        expect { Nostr.txt!("0123".b) }.must_raise EncodingError
      end

      it "enforces Integer class where expected" do
        int = 1234
        expect(Nostr.int!(int)).must_equal int
        expect { Nostr.int!('1234') }.must_raise TypeError
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

    describe "SHA256 digest" do
      it "generates 32 bytes binary, given any string" do
        strings = ["\x01\x02".b, '1234', 'asdf', '']
        digests = strings.map { |s| Nostr.digest(s) }

        digests.each { |d|
          expect(d).must_be_kind_of String
          expect(d.encoding).must_equal Encoding::BINARY
          expect(d.length).must_equal 32
        }
      end

      it "generates the same output for the same input" do
        strings = ["\x01\x02".b, '1234', 'asdf', '']
        digests = strings.map { |s| Nostr.digest(s) }

        strings.each.with_index { |s, i|
          expect(Nostr.digest(s)).must_equal digests[i]
        }
      end
    end
  end
end
