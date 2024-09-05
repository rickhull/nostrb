require 'nostrb/source'

puts "Marge Simpson: hello world"
puts

# generate keys
marge_sk, marge_pk = SchnorrSig.keypair

# create a message using the public key
marge = Nostr::Source.new(marge_pk)
hello = marge.text_note('Good morning, Homie')
signed = hello.sign(marge_sk)

puts "Content"
puts hello
puts
puts "Serialized"
puts hello.to_a.inspect
puts
puts "Signed"
puts signed.to_json
puts

#####

puts "Homer: hello back, ref prior event"
puts

homer_sk, homer_pk = SchnorrSig.keypair
homer = Nostr::Source.new(homer_pk)
response = homer.text_note('Good morning, Marge')
response.ref_event(signed.id) # reference marge's hello
signed = response.sign(homer_sk)

puts "Content"
puts response
puts
puts "Serialized"
puts response.to_a.inspect
puts
puts "Signed"
puts signed.to_json
puts

#####

puts "Maggie: love letter, ref Marge's pubkey"
puts

maggie_sk, maggie_pk = SchnorrSig.keypair
maggie = Nostr::Source.new(maggie_pk)
love_letter = maggie.text_note("Dear Mom,\nYou're the best.\nLove, Maggie")
love_letter.ref_pubkey(marge.pubkey)
signed = love_letter.sign(maggie_sk)

puts "Content"
puts love_letter
puts
puts "Serialized"
puts love_letter.to_a.inspect
puts
puts "Signed"
puts signed.to_json
puts

#####

puts "Bart uploads his profile"
puts

bart_sk, bart_pk = SchnorrSig.keypair
bart = Nostr::Source.new(bart_pk)
profile = bart.user_metadata(name: 'Bart',
                             about: 'Bartholomew Jojo Simpson',
                             picture: 'https://upload.wikimedia.org' +
                             '/wikipedia/en/a/aa/Bart_Simpson_200px.png')
signed = profile.sign(bart_sk)

puts "Content"
puts profile
puts
puts "Serialized"
puts  profile.to_a.inspect
puts
puts "Signed"
puts signed.to_json
puts

#####

puts "Lisa follows her family"
puts

lisa_sk, lisa_pk = SchnorrSig.keypair
lisa = Nostr::Source.new(lisa_pk)

pubkey_hsh = {
  marge.pubkey => ["wss://thesimpsons.com/", "marge"],
  homer.pubkey => ["wss://thesimpsons.com/", "homer"],
  bart.pubkey => ["wss://thesimpsons.com/", "bart"],
  maggie.pubkey => ["wss://thesimpsons.com/", "maggie"],
}

following = lisa.follow_list(pubkey_hsh)
signed = following.sign(lisa_sk)

puts "Content"
puts following
puts
puts "Serialized"
puts following.to_a.inspect
puts
puts "Signed"
puts signed.to_json
puts
