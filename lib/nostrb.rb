require 'schnorr_sig'
require 'json'
require 'digest'

module Nostr
  class SizeError < RuntimeError; end

  ##################
  # SHA256 Digest
  #

  def self.digest(str)
    Digest::SHA256.digest(str)
  end

  ###########
  # KeyGen
  #

  # return [secret key (binary), public key (binary), public key (hex)]
  def self.keys(sk = nil)
    sk, pk = sk.nil? ? SchnorrSig.keypair : [sk, SchnorrSig.pubkey(sk)]
    [sk, pk, SchnorrSig.bin2hex(pk)]
  end


  #####################
  # Type Checking and Enforcement
  #

  # raise TypeError or return val
  def self.check!(val, cls)
    val.is_a?(cls) ? val : raise(TypeError, "#{cls} expected: #{val.inspect}")
  end

  # enforce String
  # enforce binary/text encoding (optional)
  # enforce length (optional)
  def self.string!(str, binary: nil, length: nil)
    check!(str, String)
    if !binary.nil? and !!binary != (str.encoding == Encoding::BINARY)
      raise(EncodingError, str.encoding)
    end
    raise(SizeError, str.length) if !length.nil? and length != str.length
    str
  end

  # check String
  # check binary/text (optional)
  # check length (optional)
  # return true or false
  #   This method has similar logic to the above method, but we don't want to
  #   rescue here, nor do we want this implementation there, because the above
  #   implementation takes care to raise different types of exceptions.
  def self.string?(str, binary: nil, length: nil)
    str.is_a?(String) and
      (binary.nil? or !!binary == (str.encoding == Encoding::BINARY)) and
      (length.nil? or length == str.length)
  end

  # enforce binary encoding
  # enforce length (optional)
  def self.binary!(str, length = nil)
    string!(str, binary: true, length: length)
  end

  # check for binary encoding
  # check length (optional)
  # return true or false
  def self.binary?(str, length = nil)
    string?(str, binary: true, length: length)
  end

  # enforce nonbinary encoding
  # enforce length (optional)
  def self.text!(str, length = nil)
    string!(str, binary: false, length: length)
  end

  # check for nonbinary encoding
  # check length (optional)
  # return true or false
  def self.text?(str, length = nil)
    string?(str, binary: false, length: length)
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


  #############
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
