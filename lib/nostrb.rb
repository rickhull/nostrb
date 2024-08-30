require 'schnorr_sig'
require 'json'

module Nostr
  class SizeError < RuntimeError; end

  #
  # KeyGen
  #

  # return [secret key (binary), public key (binary), public key (hex)]
  def self.gen_keys(sk = nil)
    sk, pk = sk.nil? ? SchnorrSig.keypair : [sk, SchnorrSig.pubkey(sk)]
    [sk, pk, SchnorrSig.bin2hex(pk)]
  end

  #
  # Type Enforcement
  #

  # raise TypeError or return val
  def self.check!(val, cls)
    val.is_a?(cls) ? val : raise(TypeError, "#{cls} expected: #{val.inspect}")
  end

  # enforce String
  # enforce binary/nonbinary encoding
  # enforce length (optional)
  def self.string!(str, binary: nil, length: nil)
    check!(str, String)
    if !binary.nil? and !!binary != (str.encoding == Encoding::BINARY)
      raise(EncodingError, str.encoding)
    end
    raise(SizeError, str.length) if !length.nil? and length != str.length
    str
  end

  # enforce Integer
  def self.integer!(int)
    check!(int, Integer)
  end

  # enforce Array[Array[String]]
  def self.tags!(ary)
    check!(ary, Array).each { |a|
      check!(a, Array).each { |s|
        check!(s, String)
      }
    }
  end

  # raise (EncodingError, SizeError) or return str
  def self.binary!(str, length = nil)
    string!(str, binary: true, length: length)
  end

  # raise (EncodingError, SizeError) or return str
  def self.hex!(str, length = nil)
    string!(str, binary: false, length: length)
  end

  #
  # JSON I/O
  #

  # per NIP-01
  JSON_OPTIONS = {
    allow_nan: false,
    max_nesting: 3,
    script_safe: false,
    ascii_only: false,
    array_nl: '',
    object_nl: '',
    indent: '',
    space: '',
    space_before: '',
  }

  # convert a string of JSON; return a ruby object, likely hash or array
  def self.parse(json)
    JSON.parse(json, **JSON_OPTIONS)
  end

  # convert a ruby object, likely hash or array; return a string of JSON
  def self.json(object)
    JSON.generate(object, **JSON_OPTIONS)
  end
end
