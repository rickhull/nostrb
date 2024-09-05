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

op = Operator.generate

puts "Homer follows Marge"
homer = context['homer'][:source]
ctx = context['marge']
hsh = { ctx[:pubkey] => [ctx[:relay_url], 'marge'] }
msg = homer.follow_list(hsh)
signed = msg.sign(context['homer'][:sk])
puts op.publish(signed)
puts

puts "Marge follows Bart, Lisa, Maggie"
marge = context['marge'][:source]
hsh = {}
['bart', 'lisa', 'maggie'].each { |name|
  ctx = context[name]
  hsh[ctx[:pubkey]] = [ctx[:relay_url], name]
}
msg = marge.follow_list(hsh)
signed = msg.sign(context['marge'][:sk])
puts op.publish(signed)
puts

puts "Bart uploads his profile"
bart = context['bart'][:source]
msg = bart.user_metadata(name: 'Bart',
                         about: 'Bartholomew Jojo Simpson',
                         picture: 'https://upload.wikimedia.org' +
                         '/wikipedia/en/a/aa/Bart_Simpson_200px.png')
signed = msg.sign(context['bart'][:sk])
puts op.publish(signed)
puts

puts "Lisa follows Homer, Marge, Bart, Maggie"
lisa = context['lisa'][:source]
hsh = {}
['homer', 'marge', 'bart', 'maggie'].each { |name|
  ctx = context[name]
  hsh[ctx[:pubkey]] = [ctx[:relay_url], name]
}
msg = lisa.follow_list(hsh)
signed = msg.sign(context['lisa'][:sk])
puts op.publish(signed)
puts

puts "Maggie follows Marge"
maggie = context['maggie'][:source]
ctx = context['marge']
hsh = { ctx[:pubkey] => [ctx[:relay_url], 'marge'] }
msg = maggie.follow_list(hsh)
signed = msg.sign(context['maggie'][:sk])
puts op.publish(signed)
puts

puts "Homer gets Marge's follows"
f = Filter.new
f.add_authors(context['marge'][:pubkey])
f.add_kinds(3)
f.since = Time.now.to_i - Seconds.days(30)
op = Operator.new(context['homer'][:pubkey])
puts op.subscribe(f)
puts

# homer's contact list
# marge_pk => marge
# bart_pk => marge.bart
# lisa_pk => marge.lisa
# maggie_pk => marge.maggie

puts "Homer gets Lisa's follows"
f = Filter.new
f.add_authors(context['lisa'][:pubkey])
f.add_kinds(3)
f.since = Time.now.to_i - Seconds.days(30)
puts op.subscribe(f)
puts

# now homer has: bart_pk => marge.lisa.bart
