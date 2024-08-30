require 'nostrb/source'
require 'minitest/autorun'

include Nostr

describe Source do
  $sk, $pk, $hk = Nostr.keys

  it "wraps a hex-formatted pubkey" do
    s = Source.new(pubkey: $hk)
    expect(s).must_be_kind_of Source
    expect(s.pubkey).must_equal $hk
    expect(s.pk).must_equal $pk

    s = Source.new(pk: $pk)
    expect(s).must_be_kind_of Source
    expect(s.pubkey).must_equal $hk
    expect(s.pk).must_equal $pk

    expect { Source.new(pk: $hk) }.must_raise EncodingError
    expect { Source.new(pubkey: $pk) }.must_raise EncodingError
  end

  it "creates text_note events" do
    s = Source.new(pubkey: $hk)
    e = s.text_note('hello world')
    expect(e).must_be_kind_of Event
    expect(e.kind).must_equal 1
    expect(e.content).must_equal 'hello world'
  end

  it "creates set_metadata events" do
  end
end
