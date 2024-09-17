require 'oj'

module Nostrb
  def self.parse(json)  = Oj.load(json, mode: :strict)
  def self.json(object) = Oj.dump(object, mode: :strict)
end
