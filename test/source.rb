require 'nostrb/source'
require 'minitest/autorun'

include Nostr

describe Source do
  SK, PK = SchnorrSig.keypair
  HK = SchnorrSig.bin2hex(PK)

  it "wraps a hex-formatted pubkey" do
    s = Source.new(pubkey: HK)
    expect(s).must_be_kind_of Source
    expect(s.pubkey).must_equal HK
    expect(s.pk).must_equal PK

    s = Source.new(pk: PK)
    expect(s).must_be_kind_of Source
    expect(s.pubkey).must_equal HK
    expect(s.pk).must_equal PK

    expect { Source.new(pk: HK) }.must_raise SchnorrSig::EncodingError
    expect { Source.new(pubkey: PK) }.must_raise SchnorrSig::EncodingError
  end

  it "creates text_note events" do
    s = Source.new(pubkey: HK)
    e = s.text_note('hello world')
    expect(e).must_be_kind_of Event
    expect(e.kind).must_equal 1
    expect(e.content).must_equal 'hello world'
  end

  it "creates set_metadata events" do
  end
end
