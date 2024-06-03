require 'nostrb'      # project
require 'schnorr_sig' # gem

module Nostr
  # this class stores user profile info, keys, and is responsible for
  # creating events (messages, etc)
  class User
    attr_reader :name, :about, :picture, :sk, :pk

    def initialize(name:, about: '', picture: '', sk: nil, pk: nil)
      @name = Nostr.typecheck!(name, String)
      @about = Nostr.typecheck!(about, String)
      @picture = Nostr.typecheck!(picture, String)
      if sk
        @sk = Nostr.binary!(sk, 32)
        @pk = pk.nil? ? SchnorrSig.pubkey(@sk) : Nostr.binary!(pk, 32)
      else
        @sk, @pk = SchnorrSig.keypair
      end
    end

    def pubkey
      SchnorrSig.bin2hex @pk
    end

    # returns an Event
    def new_event(content, kind:)
      Event.new(content, kind: kind, pubkey: self.pubkey)
    end

    # returns 64 bytes binary
    def sign(event)
      event.sign(@sk)
    end

    # returns an Event, kind: 1, text_note
    def text_note(content)
      new_event(content, kind: :text_note)
    end

    # Input
    #   (about: string)
    #   (picture: string)
    # Output
    #   Event
    #     kind: 0, set_metadata
    #     content: {name: <username>, about: <string>, picture: <url, string>}
    def set_metadata(about: nil, picture: nil, **kwargs)
      @about = about if about and about != @about
      @picture = picture if picture and picture != @picture
      hash = kwargs.merge({ name:    @name,
                            about:   Nostr.typecheck!(@about, String),
                            picture: Nostr.typecheck!(@picture, String), })

      new_event(Nostr.json(hash), kind: :set_metadata)
    end
    alias_method :profile, :set_metadata

    # Input
    #   pubkey_hsh: a ruby hash of the form
    #     "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    def contact_list(pubkey_hsh)
      list = new_event('', kind: :contact_list)
      pubkey_hsh.each { |pubkey, ary|
        list.ref_pubkey(Nostr.hex!(pubkey, 64), *(ary or Array.new))
      }
      list
    end
    alias_method :follows, :contact_list

    def encrypted_text_message(content)
      new_event(content, kind: :encrypted_text_message)
    end
    alias_method :direct_msg, :encrypted_text_message
  end
end
