require 'nostrb/event'

module Nostr

  #
  # A Source holds a public key and creates Events.
  #

  class Source
    attr_reader :pk

    def initialize(pk)
      @pk = Nostr.binary!(pk, 32)
    end

    def pubkey = SchnorrSig.bin2hex(@pk)

    def event(content, kind)
      Event.new(content, kind: kind, pk: @pk)
    end

    def text_note(content) = event(content, 1)

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
      event(Nostr.json(kwargs), 0)
    end
    alias_method :profile, :set_metadata

    # Input
    #   pubkey_hsh: a ruby hash of the form
    #     "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    def contact_list(pubkey_hsh)
      list = event('', 3)
      pubkey_hsh.each { |pubkey, ary|
        list.ref_pubkey(Nostr.text!(pubkey, 64), *Nostr.check!(ary, Array))
      }
      list
    end
    alias_method :follows, :contact_list

    # TODO: WIP, DONTUSE
    def encrypted_text_message(content)
      raise "WIP"
      event(content, 4)
    end
    alias_method :direct_msg, :encrypted_text_message
  end
end
