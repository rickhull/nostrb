require 'nostrb/client'
require 'set'

c = Nostrb::Client.new('wss://localhost:7070')
sk, pk = SchnorrSig.keypair
src = Nostrb::Source.new(pk)

tag = SchnorrSig.bin2hex Random.bytes(4)

p = src.profile(name: "testing-#{tag}", about: tag, picture: tag).sign(sk)
puts "profile: #{p}"
puts c.publish(p)

e = src.text_note('hello world').sign(sk)
puts "event: #{e}"
puts c.publish(e)

# who else is out there?
# subscribe to kind:0 events in the last year
# gather pubkeys

pubkeys = Set.new

f = Nostrb::Filter.new
f.add_kinds 0
f.since = Nostrb::Filter.ago(years: 1)

puts "filter: #{f}"
c.subscribe(f) { |e| pubkeys.add e.fetch('pubkey') }
p pubkeys.to_a

puts "close:"
c.close
