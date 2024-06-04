require 'nostrb'      # project
require 'schnorr_sig' # gem

module Nostr
  # this class stores user profile info, keys, and is responsible for
  # creating events (messages, etc)
  #   name: String, somehow globally unique, TBD
  #   about: String
  #   picture: String, url
  #   sk: String, secret key, 32 bytes binary
  #   pk: String, public key, 32 bytes binary
  #   pubkey: String, public key, 64 bytes hexadecimal (ASCII)
  #   petname: String local name, no uniqueness constraint, can be overridden
  #   relay_url: String, TBD
  class User
    attr_reader :name, :about, :picture,
                :sk, :pk, :pubkey

    def initialize(name:, about: '', picture: '', sk: nil, pk: nil)
      @name = Nostr.typecheck(name, String)
      @about = Nostr.typecheck(about, String)
      @picture = Nostr.typecheck(picture, String)
      if sk
        @sk = Nostr.binary(sk, 32)
        @pk = pk.nil? ? SchnorrSig.pubkey(@sk) : Nostr.binary(pk, 32)
      else
        @sk, @pk = SchnorrSig.keypair
      end
      @pubkey = SchnorrSig.bin2hex @pk
    end

    # returns 64 bytes of hexadecimal, ASCII encoded
    def pubkey
      SchnorrSig.bin2hex @pk
    end

    # returns an Event
    def event(content, kind:)
      Event.new(content, kind: kind, pubkey: self.pubkey)
    end

    # returns 64 bytes binary
    def sign(event)
      event.sign(@sk)
    end

    # returns an Event, kind: 1, text_note
    def post(content)
      Event.text_note(content, pubkey: @pubkey)
    end

    def profile(**kwargs)
      Event.set_metadata(name: @name,
                         about:   Nostr.typecheck(@about, String),
                         picture: Nostr.typecheck(@picture, String),
                         pubkey: @pubkey,
                         **kwargs)
    end

    # pubkey: [relay_url, petname]
    # "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    def follows(pubkey_hsh)
      Event.contact_list(pubkey_hsh, pubkey: @pubkey)
    end
  end
end
