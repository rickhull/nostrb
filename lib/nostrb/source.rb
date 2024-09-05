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


  # ["EVENT", <event json>]
  # ["REQ", <subscription_id>, <filters1>, <filters2>, ...]
  # ["CLOSE", <subscription_id>]

  # filter:
  #   {
  #     "ids": <a list of event ids>,
  #     "authors": <a list of lowercase pubkeys,
  #                 the pubkey of an event must be one of these>,
  #     "kinds": <a list of a kind numbers>,
  #     "#<single-letter (a-zA-Z)>": <a list of tag values,
  #                                   for #e — a list of event ids,
  #                                   for #p — a list of pubkeys, etc.>,
  #     "since": <an integer unix timestamp in seconds.
  #               Events must have a created_at >= to this to pass>,
  #     "until": <an integer unix timestamp in seconds.
  #               Events must have a created_at <= to this to pass>,
  #     "limit": <maximum number of events relays SHOULD return
  #               in the initial query>
  #  }

  # TODO: create Nostr.filter!

  # op = Operator.new(subscription_id)

  # publish text note
  # signed = Source.new(pk).text_note('hello').sign(sk)
  # op.publish(signed) => ["EVENT", signed.to_json]

  # subscribe to an event
  # filter = { ids: [eid] }
  # op.subscribe(filter)
  # subscribe to an author

  # subscribe to profile changes in the last 5 minutes

  class Operator
    def initialize(subscription_id)
      @sid = Nostr.txt!(subscription_id)
      raise "too long" if @sid.length > 64
    end

    def publish(signed)
      Nostr.json(["EVENT", signed.to_json])
    end

    def subscribe(*filters)
      # TODO: Nostr.filter!
      Nostr.json(["REQ", @sid, *filters.each { |f| Nostr.json(f) }])
    end

    def close
      Nostr.json(["CLOSE", @sid])
    end
  end
end
