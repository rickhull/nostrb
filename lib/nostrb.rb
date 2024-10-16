require 'digest'       # stdlib
require 'schnorr_sig'  # gem

module Nostrb
  class Error < RuntimeError; end
  class SizeError < Error; end
  class FormatError < Error; end

  # return 32 bytes binary
  def self.digest(str) = Digest::SHA256.digest(str).freeze

  def self.check!(val, cls)
    val.is_a?(cls) ? val : raise(TypeError, "#{cls} expected: #{val.inspect}")
  end

  def self.int!(int, max: nil)
    check!(int, Integer)
    raise(SizeError, "#{int} > #{max} (max)") if !max.nil? and int > max
    int
  end

  def self.kind!(kind)
    int!(kind, max: 65535)
  end

  def self.ary!(ary, max: nil)
    check!(ary, Array)
    if !max.nil? and ary.length > max
      raise(SizeError, "#{ary.length} > #{max} (max)")
    end
    ary
  end

  # NOTICE: this will freeze every incoming string
  def self.str!(str, binary: nil, length: nil, max: nil)
    check!(str, String)
    if !binary.nil? and !binary == (str.encoding == Encoding::BINARY)
      raise(EncodingError, str.encoding)
    end
    raise(SizeError, str.length) if !length.nil? and str.length != length
    raise(SizeError, str.length) if !max.nil? and str.length > max
    str.freeze
  end

  def self.bin!(str, length: nil, max: nil)
    str!(str, binary: true, length: length, max: max)
  end
  def self.key!(str) = bin!(str, length: 32)


  def self.txt!(str, length: nil, max: nil)
    str!(str, binary: false, length: length, max: max)
  end
  def self.pubkey!(str) = txt!(str, length: 64)

  def self.id!(str) = txt!(str, length: 64)
  def self.sid!(str) = txt!(str, max: 64)
  def self.sig!(str) = txt!(str, length: 128)

  HELP_MSG = /\A[a-zA-Z0-9\-_]+: [[:print:]]*\z/

  def self.help!(str)
    raise(FormatError, str) unless txt!(str, max: 1024).match HELP_MSG
    str
  end

  def self.tags!(ary)
    ary!(ary, max: 9999).each { |a| ary!(a, max: 99).each { |s| txt!(s) } }
  end

  # this will use SecureRandom unless ENV['NO_SECURERANDOM']
  def self.random_hex(bytes = 32, chars: nil)
    bytes = (chars * 0.5).ceil unless chars.nil?
    SchnorrSig.bin2hex(SchnorrSig.random_bytes(bytes)).freeze
  end

  TIME_STRF = '%H:%M:%S.%L'.freeze

  def self.timestamp
    Time.now.strftime(TIME_STRF)
  end

  def self.stamp msg
    format("[%s] %s", timestamp(), msg)
  end

  # optional dependencies
  module Optional
    GEMS = %w[rbsecp256k1 oj sqlite3 sequel]

    def self.rbsecp256k1?
      begin
        require 'rbsecp256k1'; ::Secp256k1
      rescue LoadError, NameError
        false
      end
    end

    def self.oj?
      begin
        require 'oj'; ::Oj
      rescue LoadError, NameError
        false
      end
    end

    def self.sqlite3?
      begin
        require 'sqlite3'; ::SQLite3
      rescue LoadError, NameError
        false
      end
    end

    def self.sequel?
      begin
        require 'sequel'; ::Sequel
      rescue LoadError, NameError
        false
      end
    end

    def self.gem_check
      GEMS.map { |gem| [gem, self.send("#{gem}?")] }.to_h
    end
  end
end
