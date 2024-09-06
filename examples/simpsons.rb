require 'nostrb/source'

# Homer follows Marge
# Marge follows Bart, Lisa, Maggie
# Bart follows none
# Lisa follows Homer, Marge, Bart, Maggie
# Maggie follows Marge

include Nostr

pubkeys = {}   # pubkey => [relay_url, name]
simpsons = {}  # name => Source.new(pk)
keys = {}      # name => [sk, pk]
secrets = {}   # name => sk
context = {}

['homer', 'marge', 'bart', 'lisa', 'maggie'].each { |name|
  ctx = {}
  ctx[:sk], ctx[:pk] = SchnorrSig.keypair
  ctx[:pubkey] = SchnorrSig.bin2hex ctx[:pk]
  ctx[:relay_url] = ""
  ctx[:source] = Source.new(ctx[:pk])
  context[name] = ctx
}

homer, marge = context['homer'], context['marge']
bart, lisa, maggie = context['bart'], context['lisa'], context['maggie']

puts "Homer follows Marge"
hsh = { marge[:pubkey] => [marge[:relay_url], 'marge'] }
homer_follows = homer[:source].follow_list(hsh).sign(homer[:sk])
puts Source.publish(homer_follows)
puts

puts "Marge follows Bart, Lisa, Maggie"
hsh = {}
['bart', 'lisa', 'maggie'].each { |name|
  ctx = context[name]
  hsh[ctx[:pubkey]] = [ctx[:relay_url], name]
}
marge_follows = marge[:source].follow_list(hsh).sign(marge[:sk])
puts Source.publish(marge_follows)
puts

# TODO: finish from here

puts "Bart uploads his profile"
hsh = {
  name: 'Bart',
  about: 'Bartholomew Jojo Simpson',
  picture: 'https://upload.wikimedia.org/wikipedia/en/a/aa/' +
  'Bart_Simpson_200px.png',
}
bart_profile = bart[:source].user_metadata(**hsh).sign(bart[:sk])
puts Source.publish(bart_profile)
puts

puts "Lisa follows Homer, Marge, Bart, Maggie"
hsh = {}
['homer', 'marge', 'bart', 'maggie'].each { |name|
  ctx = context[name]
  hsh[ctx[:pubkey]] = [ctx[:relay_url], name]
}
lisa_follows = lisa[:source].follow_list(hsh).sign(lisa[:sk])
puts Source.publish(lisa_follows)
puts

puts "Maggie follows Marge"
hsh = { marge[:pubkey] => [marge[:relay_url], 'marge'] }
maggie_follows = maggie[:source].follow_list(hsh).sign(maggie[:sk])
puts Source.publish(maggie_follows)
puts

puts "Homer gets Marge's follows"
f = Filter.new
f.add_authors(marge[:pubkey])
f.add_kinds(3)
f.since = Time.now.to_i - Seconds.days(30)
puts Source.subscribe(homer[:pubkey], f)
puts

puts Source.publish(marge_follows)
puts

# homer's contact list
# marge_pk => marge
# bart_pk => marge.bart
# lisa_pk => marge.lisa
# maggie_pk => marge.maggie

puts "Homer gets Lisa's follows"
f = Filter.new
f.add_authors(lisa[:pubkey])
f.add_kinds(3)
f.since = Time.now.to_i - Seconds.days(30)
puts Source.subscribe(homer[:pubkey], f)
puts

puts Source.publish(lisa_follows)
puts

# now homer has: bart_pk => marge.lisa.bart
