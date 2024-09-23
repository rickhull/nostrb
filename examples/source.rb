require 'nostrb/source'

include Nostrb

puts "Marge Simpson: hello world"
puts

# generate keys
sk, pk = SchnorrSig.keypair

# create a message using the public key
marge = Source.new(pk)
hello = marge.text_note('Good morning, Homie')
signed = hello.sign(sk)

puts "Content: #{hello}"
puts
puts "Serialized: #{hello.to_a.inspect}"
puts
puts "Signed: #{signed.to_h}"
puts

#####

puts "Homer: hello back, ref prior event"
puts

sk, pk = SchnorrSig.keypair
homer = Source.new(pk)
hello2 = homer.text_note('Good morning, Marge')
hello2.ref_event(signed.id) # reference marge's hello
signed = hello2.sign(sk)

puts "Content: #{hello2}"
puts
puts "Serialized: #{hello2.to_a.inspect}"
puts
puts "Signed: #{signed.to_h}"
puts

#####

puts "Maggie: love letter, ref Marge's pubkey"
puts

sk, pk = SchnorrSig.keypair
maggie = Source.new(pk)
love_letter = maggie.text_note("Dear Mom,\nYou're the best.\nLove, Maggie")
love_letter.ref_pubkey(marge.pubkey)
signed = love_letter.sign(sk)

puts "Content: #{love_letter}"
puts
puts "Serialized: #{love_letter.to_a.inspect}"
puts
puts "Signed: #{signed.to_h}"
puts

#####

puts "Bart uploads his profile"
puts

sk, pk = SchnorrSig.keypair
bart = Source.new(pk)
profile = bart.user_metadata(name: 'Bart',
                             about: 'Bartholomew Jojo Simpson',
                             picture: 'https://upload.wikimedia.org' +
                             '/wikipedia/en/a/aa/Bart_Simpson_200px.png')
signed = profile.sign(sk)

puts "Content: #{profile}"
puts
puts "Serialized: #{profile.to_a.inspect}"
puts
puts "Signed: #{signed.to_h}"
puts

#####

puts "Lisa follows her family"
puts

sk, pk = SchnorrSig.keypair
lisa = Source.new(pk)

pubkey_hsh = {
  marge.pubkey => ["wss://thesimpsons.com/", "marge"],
  homer.pubkey => ["wss://thesimpsons.com/", "homer"],
  bart.pubkey => ["wss://thesimpsons.com/", "bart"],
  maggie.pubkey => ["wss://thesimpsons.com/", "maggie"],
}

following = lisa.follow_list(pubkey_hsh)
signed = following.sign(sk)

puts "Content: #{following}"
puts
puts "Serialized: #{following.to_a.inspect}"
puts
puts "Signed: #{signed.to_h}"
puts
