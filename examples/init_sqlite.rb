require 'nostrb/sqlite'
require 'nostrb/event'

include Nostrb::SQLite

# setup database
puts Setup.new.setup
puts

# create event
sk, pk = SchnorrSig.keypair
event = Nostrb::Event.new('', pk: pk).sign(sk)
puts "Created Event"
puts event.to_h
puts

# store event
writer = Writer.new
writer.add_event event.to_h

# retrieve event
reader = Reader.new
rs = reader.select_events
hsh = Reader.hydrate(rs.next_hash)
puts "Retrieved Event"
puts hsh
puts

# compare to original
rs.close
puts "Faithful retrieval: #{hsh == event.to_h ? 'SUCCESS' : 'FAIL'}"
puts


# create new event with tags
e2 = Nostrb::Event.new('yo', pk: pk)
e2.ref_event(event.id)
e2 = e2.sign(sk)
puts "Created Event with tags"
puts e2.to_h
puts

# store event
writer.add_event e2.to_h

# retrieve event
hsh = {}
reader.process_events.each { |h|
  if h['id'] == e2.id
    hsh = h
    puts "Retrieved Event"
    puts hsh
    puts
  end
}

# compare to original
puts "Faithful retrieval: #{hsh == e2.to_h ? 'SUCCESS' : 'FAIL'}"
puts

puts "events"
results = reader.select_events
p results.columns
results.each { |row| p row }
puts

puts "tags"
results = reader.db.query("SELECT * FROM tags")
p results.columns
results.each { |row| p row }
puts
