require 'nostrb/event' #  project

module Nostr

  #
  # A Source holds a public key and creates Events.
  #

  class Source
    attr_reader :pubkey

    def initialize(pubkey: nil, pk: nil)
      if pubkey
        @pubkey = Nostr.hex!(pubkey, 64)
      elsif pk
        @pubkey = SchnorrSig.bin2hex(Nostr.binary!(pk, 32))
      else
        raise "public key is required"
      end
    end

    def pk
      SchnorrSig.hex2bin @pubkey
    end

    # returns an Event, kind: 1, text_note
    def text_note(content)
      Event.new(Nostr.string!(content), kind: 1, pubkey: @pubkey)
    end

    # Input
    #   name: string
    #   about: string
    #   picture: string, URL
    # Output
    #   Event
    #     kind: 0, set_metadata
    #     content: {
    #       name: <username>, about: <string>, picture: <url, string>
    #     }
    def set_metadata(**kwargs)
      Nostr.string!(kwargs.fetch(:name))
      Nostr.string!(kwargs.fetch(:about))
      Nostr.string!(kwargs.fetch(:picture))

      Event.new(Nostr.json(kwargs), kind: 0, pubkey: @pubkey)
    end
    alias_method :profile, :set_metadata

    # Input
    #   pubkey_hsh: a ruby hash of the form
    #     "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    def contact_list(pubkey_hsh)
      list = Event.new('', kind: 3, pubkey: @pubkey)
      pubkey_hsh.each { |pubkey, ary|
        list.ref_pubkey(Nostr.hex!(pubkey, 64), *Nostr.check!(ary, Array))
      }
      list
    end
    alias_method :follows, :contact_list

    # TODO: WIP, DONTUSE
    def encrypted_text_message(content)
      Event.new(Nostr.string!(content), kind: 4, pubkey: @pubkey)
    end
    alias_method :direct_msg, :encrypted_text_message
  end
end
