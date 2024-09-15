require 'nostrb'
require 'minitest/autorun'

describe Nostrb do
  describe "module functions" do
    describe "type enforcement" do
      it "can check any class" do
        str = 'asdf'
        expect(Nostrb.check!(str, String)).must_equal str
        expect { Nostrb.check!(str, Range) }.must_raise TypeError

        range = (0..10)
        expect(Nostrb.check!(range, Range)).must_equal range
        expect { Nostrb.check!(range, Symbol) }.must_raise TypeError

        sym = :symbol
        expect(Nostrb.check!(sym, Symbol)).must_equal sym
        expect { Nostrb.check!(sym, String) }.must_raise TypeError
      end

      it "validates a text (possibly hex) string" do
        hex = "0123456789abcdef"

        expect(Nostrb.txt!(hex)).must_equal hex
        expect(Nostrb.txt!(hex, length: 16)).must_equal hex
        expect { Nostrb.txt!(hex, length: 8) }.must_raise Nostrb::SizeError
        expect { Nostrb.txt!("0123".b) }.must_raise EncodingError
      end

      it "enforces Integer class where expected" do
        int = 1234
        expect(Nostrb.int!(int)).must_equal int
        expect { Nostrb.int!('1234') }.must_raise TypeError
      end

      it "enforces a particular tag structure where expected" do
        # Array[Array[String]]
        tags = [['a', 'b', 'c'], ['1', '2', '3', '4']]
        expect(Nostrb.tags!(tags)).must_equal tags

        [
          ['a', 'b', 'c', '1' , '2', '3', '4'],  # Array[String]
          [['a', 'b', 'c'], [1, 2, 3, 4]],       # Array[Array[String|Integer]]
          ['a', 'b', 'c', ['1' , '2', '3', '4']],# Array[Array | String]
          'a',                                   # String
          [[:a, :b, :c], [1, 2, 3, 4]],          # Array[Array[Symbol|String]]
        ].each { |bad|
          expect { Nostrb.tags!(bad) }.must_raise TypeError
        }
      end
    end

    describe "JSON I/O" do
      it "parses a JSON string to a Ruby object" do
        expect(Nostrb.parse('{}')).must_equal Hash.new
        expect(Nostrb.parse('[]')).must_equal Array.new
      end

      it "generates JSON from a Ruby hash or array" do
        expect(Nostrb.json({})).must_equal '{}'
        expect(Nostrb.json([])).must_equal '[]'
      end
    end

    describe "SHA256 digest" do
      it "generates 32 bytes binary, given any string" do
        strings = ["\x01\x02".b, '1234', 'asdf', '']
        digests = strings.map { |s| Nostrb.digest(s) }

        digests.each { |d|
          expect(d).must_be_kind_of String
          expect(d.encoding).must_equal Encoding::BINARY
          expect(d.length).must_equal 32
        }
      end

      it "generates the same output for the same input" do
        strings = ["\x01\x02".b, '1234', 'asdf', '']
        digests = strings.map { |s| Nostrb.digest(s) }

        strings.each.with_index { |s, i|
          expect(Nostrb.digest(s)).must_equal digests[i]
        }
      end
    end
  end
end
