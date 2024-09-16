require 'oj'

module Nostrb
  # per NIP-01
  Oj.default_options = {
    nan: :raise,        # raise on NaN / Infinity
    indent: 0,          # full squish
    safe: true,         # limit size of ParseErrors
    escape_mode: :json, # default, not ASCII- or XSS-safe
    max_nesting: 4,     # sanity check; wire format is 4 deep
  }

  def self.parse(json)  = Oj.load(json)
  def self.json(object) = Oj.dump(object)
end
