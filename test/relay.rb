require 'nostrb/relay'
require 'minitest/autorun'

include Nostr

describe Server do
  describe "class functions" do
    it "has an EVENT response" do
    end

    it "has an OK response" do
    end

    it "has an EOSE response" do
    end

    it "has a CLOSED response" do
    end

    it "has a NOTICE response" do
    end

    it "formats Exceptions" do
    end

    it "uses NOTICE to return errors" do
    end
  end

  it "has no initialization parameters" do
    s = Server.new
    expect(s).must_be_kind_of Server
  end

  it "stores inbound events" do
  end

  it "has a single response to EVENT requests" do
    # respond error / NOTICE
    # respond OK: false
    # respond OK: true
  end

  it "has multiple responses to REQ requets" do
    # respond EVENT
    # respond EVENT
    # ...
    # respond EOSE
  end

  it "has a single response to CLOSE requests" do
    # respond CLOSED
  end
end
