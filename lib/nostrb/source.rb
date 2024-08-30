require 'nostrb/event'

module Nostr

  #
  # A Source holds a public key and creates Events.
  #

  class Source
    attr_reader :pubkey

    def initialize(pubkey)
      @pubkey = Nostr.text!(pubkey, 64)
    end

    # returns an Event, kind: 1, text_note
    def text_note(content)
      Event.new(content, kind: 1, pubkey: @pubkey)
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
      Nostr.text!(kwargs.fetch(:name))
      Nostr.text!(kwargs.fetch(:about))
      Nostr.text!(kwargs.fetch(:picture))

      Event.new(Nostr.json(kwargs), kind: 0, pubkey: @pubkey)
    end
    alias_method :profile, :set_metadata

    # Input
    #   pubkey_hsh: a ruby hash of the form
    #     "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    def contact_list(pubkey_hsh)
      list = Event.new('', kind: 3, pubkey: @pubkey)
      pubkey_hsh.each { |pubkey, ary|
        list.ref_pubkey(Nostr.text!(pubkey, 64), *Nostr.check!(ary, Array))
      }
      list
    end
    alias_method :follows, :contact_list

    # TODO: WIP, DONTUSE
    def encrypted_text_message(content)
      raise "WIP"
      Event.new(content, kind: 4, pubkey: @pubkey)
    end
    alias_method :direct_msg, :encrypted_text_message
  end
end
