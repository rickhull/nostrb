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
      pubkey_hsh.each { |pubkey, (url, name)|
        list.ref_pubkey(Nostr.txt!(pubkey, 64),
                        Nostr.txt!(url),
                        Nostr.txt!(name))
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

  module Seconds
    def milliseconds(i)
      i / 1000r
    end

    def seconds(i)
      i
    end

    def minutes(i)
      60 * i
    end

    def hours(i)
      60 * minutes(i)
    end

    def days(i)
      24 * hours(i)
    end

    def weeks(i)
      7 * days(i)
    end

    def months(i)
      30 * days(i)
    end

    def years(i)
      365 * days(i)
    end
  end
  Seconds.extend(Seconds)

  class Filter
    def initialize
      @ids = []
      @authors = []
      @kinds = []
      @tags = {}
      @since = nil
      @until = nil
      @limit = nil
    end

    def add_ids(*event_ids)
      @ids += event_ids.each { |id| Nostr.txt!(id, 64) }
    end

    def add_authors(*pubkeys)
      @authors += pubkeys.each { |pubkey| Nostr.txt!(pubkey, 64) }
    end

    def add_kinds(*kinds)
      @kinds += kinds.each { |k| Nostr.kind!(k) }
    end

    def add_tag(letter, list)
      @tags[Nostr.txt!(letter, 1)] = Nostr.ary!(list, 99).each { |s|
        Nostr.txt!(s)
      }
    end

    def since=(int)
      @since = Nostr.int!(int)
    end

    def until=(int)
      @until = Nostr.int!(int)
    end

    def limit=(int)
      @limit = Nostr.int!(int)
    end

    def to_h
      h = Hash.new
      h["ids"] = @ids if !@ids.empty?
      h["authors"] = @authors if !@authors.empty?
      h["kinds"] = @kinds if !@kinds.empty?
      @tags.each { |letter, ary|
        h['#' + letter.to_s] = ary if !ary.empty?
      }
      h["since"] = @since unless @since.nil?
      h["until"] = @until unless @until.nil?
      h["limit"] = @limit unless @limit.nil?
      h
    end
  end

  class Operator
    # add a 4th layer of nesting for the array wrapper
    JSON_OPTIONS = Nostr::JSON_OPTIONS.merge(max_nesting: 4)

    def self.json(array) = JSON.generate(Nostr.ary!(array), **JSON_OPTIONS)
    def self.sid = SchnorrSig.bin2hex Random.bytes(32)
    def self.generate = new(self.sid)

    def initialize(subscription_id)
      @sid = Nostr.txt!(subscription_id)
      raise "too long" if @sid.length > 64
    end

    def publish(signed) = Operator.json(["EVENT", signed.to_h])

    def subscribe(*filters)
      Operator.json(["REQ", @sid,
                     *filters.map { |f| Nostr.check!(f, Filter).to_h }])
    end

    def close = Operator.json(["CLOSE", @sid])
  end

  # Not used
  class Contact
    attr_reader :name, :pubkey, :relays

    def initialize(name, pubkey, *relay_urls)
      @name = Nostr.txt!(name)
      @pubkey = Nostr.txt!(pubkey, 64)
      @relays = relay_urls.each { |u| Nostr.txt!(u) }
    end
  end
end
