require 'nostrb/source'

include Nostr

sk, pk = SchnorrSig.keypair
source = Source.new(pk)

puts "Public key:"
puts source.pubkey
puts

msg = source.text_note('hello world')

puts "Created message:"
puts msg.to_a.inspect
puts

signed = msg.sign(sk)

puts "Signed message:"
puts signed.to_h
puts

# msg is ready for delivery
# relay receives JSON string

puts "Relay receives:"
puts signed.to_json
puts

# verify the signature
# if no errors raised, signature is verified
# decompose into fields (Ruby hash buckets)

hash = SignedEvent.verify(signed.to_json)
puts "Signature verified:"
p hash
puts

# show that the relay faithfully recreates the original serialization
# this is required to verify the id and ultimately the signature
# which we have already done

puts "Relay serialization:"
puts Event.serialize(hash).inspect
puts

# if we had to: send received json to the the destination

puts "Relay sends:"
puts signed.to_json
puts
