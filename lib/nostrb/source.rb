require 'nostrb/event'
require 'nostrb/filter'

module Nostrb

  #
  # A Source holds a public key and creates Events.
  #

  class Source
    #######################
    # Client Requests

    def self.publish(signed) = ["EVENT", signed.to_h].freeze

    def self.subscribe(sid, *filters)
      ["REQ", Nostrb.sid!(sid), *filters.map { |f|
         Nostrb.check!(f, Filter).to_h
      }].freeze
    end

    def self.close(sid) = ["CLOSE", Nostrb.sid!(sid)].freeze

    #######################
    # Utils / Init

    def self.random_sid
      SchnorrSig.bin2hex(Random.bytes(32)).freeze
    end

    attr_reader :pk

    def initialize(pk)
      @pk = Nostrb.key!(pk).freeze
    end

    def pubkey = SchnorrSig.bin2hex(@pk).freeze

    ############################
    # Event Creation

    def event(content, kind)
      Event.new(content, kind: kind, pk: @pk)
    end

    #           NIP-01
    # Input
    #   content: string
    # Output
    #   Event
    #     content: <content>
    #     kind: 1
    def text_note(content)
      event(content, 1)
    end

    #           NIP-01
    # Input
    #   name: string
    #   about: string
    #   picture: string, URL
    # Output
    #   Event
    #     content: {"name":<username>,"about":<string>,"picture":<url>}
    #     kind: 0, user metadata
    #     optional content fields:
    #       display_name: <string>
    #       website: <url>
    #       banner: <url, picture>
    #       bot: <boolean>
    def user_metadata(name:, about:, picture:, **kwargs)
      full = kwargs.merge(name: Nostrb.txt!(name),
                          about: Nostrb.txt!(about),
                          picture: Nostrb.txt!(picture))
      event(Nostrb.json(full), 0)
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
        list.ref_pubkey(Nostrb.pubkey!(pubkey),
                        Nostrb.txt!(url),
                        Nostrb.txt!(name))
      }
      list
    end
    alias_method :follows, :follow_list

    def relay_list(url_hsh)
      list = event('', 10002)
      url_hsh.each { |url, rw_flag|
        case rw_flag
        when nil, :read_write
          # read/write
          list.add_tag('r', url)
        when :read
          list.add_tag('r', url, 'read')
        when :write
          list.add_tag('r', url, 'write')
        else
          raise('unexpected')
        end
      }
      list
    end

    #           NIP-09
    # Input
    #   explanation: content string
    #   *event_ids: array of event ids, hex format
    # Output
    #   Event
    #     content: explanation
    #     kind: 5, deletion request
    #     tags: [['e', event_id]]
    # TODO: support deletion of replaceable events ('a' tags)
    def deletion_request(explanation, *event_ids)
      e = event(explanation, 5)
      event_ids.each { |eid| e.ref_event(eid) }
      e
    end
    alias_method :delete, :deletion_request
  end
end
