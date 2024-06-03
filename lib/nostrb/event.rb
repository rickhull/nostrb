require 'nostrb/user' # project
require 'digest'      # stdlib
require 'schnorr_sig' # gem

module Nostr
  class Event
    class Error < RuntimeError; end
    class KeyError < Error; end

    # id: 32 bytes (hex = 64)
    # pubkey: 32 bytes (hex = 64)
    # created_at: unix seconds
    # kind: 0..65535
    # tags: []
    # content: "hello world"
    # sig: 64 bytes (hex = 128)

    # the id is a SHA256 of the serialized event:
    # [
    #   0,
    #   <pubkey, lowercase hex>,
    #   <created at>,
    #   <kind>,
    #   <tags>,
    #   <content>
    # ]

    # 1. using public key:
    # 1a. generate content: "hello world"
    # 1b. set kind
    # 1c. set tags
    # 2. timestamp
    # 3. generate id
    #
    # 4. sign (requires id and priv key)

    KINDS = {
      set_metadata: 0,
      text_note: 1,
      # recommend_server: 2, deprecated
      contact_list: 3,
      encrypted_direct_message: 4,
    }

    def self.kind(val)
      case val
      when 0, 1, 3, 4
        val
      when 2, :recommend_server
        raise(Error, "kind value 2 is deprecated")
      else
        KINDS.fetch(val)
      end
    end

    # returns 64 byte binary string
    def self.sign(msg, secret_key)
      SchnorrSig.sign(secret_key, msg)
    end

    attr_reader :content, :kind, :created_at, :pubkey, :signature

    def initialize(content = '', kind: :text_note, pubkey:)
      @content = Nostr.typecheck!(content, String)
      @kind = Event.kind(kind)
      @pubkey = Nostr.hex!(pubkey, 64)
      @tags = []
      @created_at = nil
      @digest = nil
      @signature = nil
    end

    # conditionally initialize @created_at, return ruby array
    def serialize
      [0,
       @pubkey,
       @created_at ||= Time.now.to_i,
       @kind,
       @tags,
       @content]
    end

    # assign @digest, return 32 bytes binary
    def digest(memo: true)
      return @digest if memo and @digest

      # we are creating or recreating the event
      @created_at = nil
      @digest = Digest::SHA256.digest Nostr.json(self.serialize)
    end

    # return 64 bytes of hexadecimal, ASCII encoded
    def id
      SchnorrSig.bin2hex self.digest(memo: true)
    end

    # assign @signature, return 64 bytes binary
    def sign(secret_key)
      Nostr.binary!(secret_key, 32)
      @signature = SchnorrSig.sign(secret_key, self.digest(memo: true))
    end

    # return 128 bytes of hexadecimal, ASCII encoded
    def sig
      SchnorrSig.bin2hex(@signature) if @signature
    end

    # return a Ruby hash, suitable for JSON conversion to NIPS01 Event object
    def object
      {
        id: self.id,
        pubkey: @pubkey,
        created_at: @created_at,
        kind: @kind,
        tags: @tags,
        content: @content,
        sig: self.sig,
      }
    end

    # add an array of 2+ strings to @tags
    def add_tag(tag, value, *rest)
      @tags.push([Nostr.typecheck!(tag, String),
                  Nostr.typecheck!(value, String)] +
                 rest.each { |s| Nostr.typecheck!(s, String) })
    end

    # add an event tag based on event id, hex encoded
    def ref_event(eid_hex, *rest)
      add_tag('e', Nostr.hex!(eid_hex, 64), *rest)
    end

    # add a pubkey tag based on pk, 32 bytes binary
    def ref_pk(pk, *rest)
      add_tag('p', SchnorrSig.bin2hex(Nostr.binary!(pk, 32)), *rest)
    end

    # add a pubkey tag based on pubkey, 64 bytes hex encoded
    def ref_pubkey(pk_hex, *rest)
      add_tag('p', Nostr.hex!(pk_hex, 64), *rest)
    end

    # kind: and one of [pubkey:, pk:] required
    def ref_replace(*rest, kind:, pubkey: nil, pk: nil, d_tag: nil)
      raise(ArgumentError, "public key required") if pubkey.nil? and pk.nil?
      pubkey ||= SchnorrSig.bin2hex(pk)
      val = [Event.kind(kind), Nostr.hex!(pubkey, 64), d_tag].join(':')
      add_tag('a', val, *rest)
    end
  end
end


if __FILE__ == $0
  # keypair will be generated
  marge = Nostr::User.new(name: 'Marge')
  hello = marge.text_note('Hi Homie')

  puts "Marge Simpson: hello world"
  puts

  puts "Serialized"
  p hello.serialize
  puts

  marge.sign(hello)

  puts "Event Object"
  p hello.object

  puts
  puts
  puts "goodnight"
  puts

  goodnight = marge.text_note('Goodnight Homer')
  goodnight.ref_event(hello.id)

  puts "Serialized"
  p goodnight.serialize
  puts

  marge.sign(goodnight)

  puts "Event Object"
  p goodnight.object


  puts
  puts
  puts "homer loves marge"
  puts

  # use our own secret key; pubkey will be generated
  homer = Nostr::User.new(name: 'Homer', about: 'Homer Jay Simpson',
                          sk: Random.bytes(32))
  love_letter = homer.text_note("I love you Marge.\nLove, Homie")
  love_letter.ref_pubkey(SchnorrSig.bin2hex(marge.pk))

  puts "Serialized"
  p love_letter.serialize
  puts

  homer.sign(love_letter)

  puts "Event Object"
  p love_letter.object


  puts
  puts
  puts "bart uploads his profile"
  puts


  # we'll "bring our own" keypair
  sk, pk = SchnorrSig.keypair
  bart = Nostr::User.new(name: 'Bart',
                         about: 'Bartholomew Jojo Simpson',
                         picture: 'https://upload.wikimedia.org/wikipedia/en/a/aa/Bart_Simpson_200px.png',
                         sk: sk, pk: pk)
  profile = bart.set_metadata

  puts "Serialized"
  p profile.serialize
  puts

  bart.sign(profile)

  puts "Event Object"
  p profile.object
  puts

  puts "Profile Content"
  puts profile.content


  puts
  puts
  puts "lisa follows her family"
  puts

  lisa = Nostr::User.new(name: 'Lisa')
  # keys = [marge.pk, homer.pk, bart.pk
  following = lisa.contact_list({ marge.pubkey => [],
                                  homer.pubkey => [],
                                  bart.pubkey  => [], })

  puts "Serialized"
  p following.serialize
  puts

  lisa.sign(profile)

  puts "Event Object"
  p following.object
end
