require 'nostrb/event'

include Nostrb

puts "Key Generation"
sk, pk = SchnorrSig.keypair
secret_key, pubkey = [sk, pk].map { |s| SchnorrSig.bin2hex s }
puts "Secret key: #{secret_key}"
puts "Public key: #{pubkey}"
puts

puts "Hello World"
puts "==========="
puts

puts "Serialized"
event = Event.new('hello world', pk: pk)
puts event.to_a.inspect
puts

puts "Signed Hash"
signed = event.sign(sk)
puts signed.to_h
puts

puts "Signed JSON"
puts Nostrb.json(signed.to_h)
puts

puts
puts "Tagged Event"
puts "============"
puts

puts "Serialized"
tagged = Event.new('goodbye world', pk: pk)
tagged.ref_event(signed.id)
puts tagged.to_a.inspect
puts

puts "Signed Hash"
signed = tagged.sign(sk)
puts signed.to_h
puts

puts "Signed JSON"
puts Nostrb.json(signed.to_h)
puts
