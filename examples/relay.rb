require 'nostrb/source'
require 'nostrb/relay'

# Bart uploads his profile; pubkey now discoverable
# Marge requests recent profiles; discovers Bart's pubkey
# Marge follows Bart
# Marge uploads her profile
# Homer requests recent profiles; discovers Marge's and Bart's pubkeys
# Homer follows Marge
# Lisa uploads her profile
# Maggie uploads her profile
# Marge requests recent profiles; discovers Lisa, Maggie
# Marge follows Bart, Lisa, Maggie
# Homer requests Marge's recent follows; discovers Lisa and Maggie

TABLE_DUMP = true
#TABLE_DUMP = false

STORAGE = :sqlite
#STORAGE = :sequel

include Nostrb

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

relay = Server.new(storage: STORAGE)

puts "Bart uploads his profile"
hsh = {
  name: 'Bart',
  about: 'Bartholomew Jojo Simpson',
  picture: 'https://upload.wikimedia.org/wikipedia/en/a/aa/' +
  'Bart_Simpson_200px.png',
}
bart_profile = bart[:source].user_metadata(**hsh).sign(bart[:sk])
json = Nostrb.json Source.publish(bart_profile)
puts json
puts

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

puts "Marge requests recent profiles"
f = Filter.new
f.add_kinds(0)
f.since(minutes: 30)
json = Nostrb.json Source.subscribe(marge[:pubkey], f)
puts json

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

# marge contacts:
# bart_pk => bart

puts "Marge follows Bart"
hsh = { bart[:pubkey] => ["", 'bart'] }
marge_follows = marge[:source].follow_list(hsh).sign(marge[:sk])
json = Nostrb.json Source.publish(marge_follows)
puts json
puts

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

puts "Marge uploads her profile"
hsh = {
  name: 'Marge',
  about: 'Mama Simpson',
  picture: '',
}
marge_profile = marge[:source].user_metadata(**hsh).sign(marge[:sk])
json = Nostrb.json Source.publish(marge_profile)
puts json
puts

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

puts "Homer requests recent profiles"
f = Filter.new
f.add_kinds(0)
f.since(minutes: 30)
json = Nostrb.json Source.subscribe(homer[:pubkey], f)
puts json

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

# homer contacts:
# marge_pk => marge
# bart_pk => bart

puts "Homer follows Marge"
hsh = { marge[:pubkey] => ['', 'marge'] }
homer_follows = homer[:source].follow_list(hsh).sign(homer[:sk])
json = Nostrb.json Source.publish(homer_follows)
puts json
puts

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

puts "Lisa uploads her profile"
hsh = {
  name: 'Lisa',
  about: 'Concise yet adventurous',
  picture: '',
}
lisa_profile = lisa[:source].user_metadata(**hsh).sign(lisa[:sk])
json = Nostrb.json Source.publish(lisa_profile)
puts json
puts

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

puts "Maggie uploads her profile"
hsh = {
  name: 'Maggie',
  about: 'Ga ga goo ga (squeal)',
  picture: '',
}
maggie_profile = maggie[:source].user_metadata(**hsh).sign(maggie[:sk])
json = Nostrb.json Source.publish(maggie_profile)
puts json
puts

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts


puts "Marge requests recent profiles"
f = Filter.new
f.add_kinds(0)
f.since(minutes: 30)
json = Nostrb.json Source.subscribe(marge[:pubkey], f)
puts json

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

# marge contacts:
# bart_pk => bart
# lisa_pk => lisa
# maggie_pk => maggie

puts "Marge follows Bart, Lisa, Maggie"
hsh = {
  lisa[:pubkey] => ['', 'lisa'],
  maggie[:pubkey] => ['', 'maggie'],
}
marge_follows = marge[:source].follow_list(hsh).sign(marge[:sk])
json = Nostrb.json Source.publish(marge_follows)
puts json
puts

puts "Relay response:"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

puts "Homer requests Marge's follows"
f = Filter.new
f.add_authors(marge[:pubkey])
f.add_kinds(3)
f.since(days: 30)
json = Nostrb.json Source.subscribe(homer[:pubkey], f)
puts json
puts

puts "Relay response"
relay.ingest(json).each { |r| puts Nostrb.json(r) }
puts

# homer contacts:
# marge_pk => marge
# bart_pk => bart
# lisa_pk => marge.lisa
# maggie_pk => marge.maggie

if TABLE_DUMP
  reader = case STORAGE
           when :sqlite then Nostrb::SQLite::Reader.new
           when :sequel then Nostrb::Sequel::Reader.new
           else
             raise 'unexpected'
           end

  puts "events"
  count = 0
  events = reader.select_events
  p events.columns
  events.each { |row|
    p row.is_a?(Hash) ? row.values : row
    count += 1
  }
  puts "Count: #{count}"
  puts

  puts "tags"
  count = 0
  tags = if STORAGE == :sqlite
           reader.db.query("SELECT * FROM tags")
         else
           reader.db[:tags]
         end
  p tags.columns
  tags.each { |row|
    p row.is_a?(Hash) ? row.values : row
    count += 1
  }
  puts "Count: #{count}"
  puts

  puts "r_events"
  count = 0
  r_events = if STORAGE == :sqlite
               reader.db.query("SELECT * FROM r_events")
             else
               reader.db[:r_events]
             end
  p r_events.columns
  r_events.each { |row|
    p row.is_a?(Hash) ? row.values : row
    count += 1
  }
  puts "Count: #{count}"
  puts

  puts "r_tags"
  count = 0
  r_tags = if STORAGE == :sqlite
             reader.db.query("SELECT * FROM r_tags")
           else
             reader.db[:r_tags]
           end
  p r_tags.columns
  r_tags.each { |row|
    p row.is_a?(Hash) ? row.values : row
    count += 1
  }
  puts "Count: #{count}"
  puts
end
