require 'nostrb' # provides Nostrb::Error

module Nostrb
  OJ = begin
         require 'oj'
       rescue LoadError
         require 'json'
         false
       end

  class JSONError < Error; end

  if OJ

    # Oj.load
    def self.parse(json)
      begin
        Oj.load(json, mode: :strict).freeze
      rescue StandardError => e
        raise(JSONError, e.message)
      end
    end

    # Oj.dump
    def self.json(object)
      begin
        Oj.dump(object, mode: :strict).freeze rescue JSONError
      rescue StandardError => e
        raise(JSONError, e.message)
      end
    end

  else

    JSON_OPTIONS = {
      allow_nan: false,
      max_nesting: 4,
      script_safe: false,
      ascii_only: false,
      array_nl: '',
      object_nl: '',
      indent: '',
      space: '',
      space_before: '',
    }

    # JSON.parse
    def self.parse(json)
      begin
        JSON.parse(json, **JSON_OPTIONS).freeze
      rescue StandardError => e
        raise(JSONError, e.message)
      end
    end

    # JSON.generate
    def self.json(object)
      begin
        JSON.generate(object, **JSON_OPTIONS).freeze
      rescue StandardError => e
        raise(JSONError, e.message)
      end
    end

  end
end
