require 'nostrb/event'

module Nostr

  #
  # A Source holds a public key and creates Events.
  #

  class Source
    attr_reader :pk

    def initialize(pk)
      @pk = Nostr.bin!(pk, 32)
    end

    def pubkey = SchnorrSig.bin2hex(@pk)

    def event(content, kind)
      Event.new(content, kind: kind, pk: @pk)
    end

    #           NIP-01
    def text_note(content) = event(content, 1)

    #           NIP-01
    # Input
    #   name: string
    #   about: string
    #   picture: string, URL
    # Output
    #   Event
    #     content: {"name":<username>,"about":<string>,"picture":<url>}
    #     kind: 0, user metadata
    def user_metadata(name:, about:, picture:, **kwargs)
      full = kwargs.merge(name: Nostr.txt!(name),
                          about: Nostr.txt!(about),
                          picture: Nostr.txt!(picture))
      event(Nostr.json(full), 0)
    end
    alias_method :profile, :user_metadata

    #           NIP-02
    # Input
    #   pubkey_hsh: a ruby hash of the form: pubkey => [relay_url, petname]
    #     "deadbeef1234abcdef" => ["wss://alicerelay.com/", "alice"]
    # Output
    #   Event
    #     content: ""
    #     kind: 3, follow list
    #     tags: [['p', pubkey, relay_url, petname]]
    def follow_list(pubkey_hsh)
      list = event('', 3)
      pubkey_hsh.each { |pubkey, ary|
        Nostr.ary!(ary).each { |s| Nostr.txt!(s) }
        list.ref_pubkey(Nostr.txt!(pubkey, 64), *ary)
      }
      list
    end
    alias_method :follows, :follow_list

    #           NIP-09
    # Input
    #   explanation: content string
    #   event_ids: array of event ids, hex format
    # Output
    #   Event
    #     content: explanation
    #     kind: 5, deletion request
    #     tags: [['e', event_id]]
    # TODO: support deletion of replaceable events ('a' tags)
    def deletion_request(explanation, event_ids)
      e = event(explanation, 5)
      event_ids.each { |eid| e.ref_event(eid) }
      e
    end
    alias_method :delete, :deletion_request
  end
end
