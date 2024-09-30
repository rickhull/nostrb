require 'nostrb/sequel'

filename = 'testing.db'

sql = Nostrb::SQLite::Setup.new(filename)
seq = Nostrb::Sequel::Setup.new(filename)

sql.setup
sql_setup_sql_report = sql.report
sql_setup_seq_report = seq.report

seq.setup
seq_setup_sql_report = sql.report
seq_setup_seq_report = seq.report

same = sql_setup_sql_report == seq_setup_sql_report

puts "SQLite::Storage#report"
puts "  SQLite::Setup"
puts sql_setup_sql_report
puts
puts "  Sequel::Setup"
puts seq_setup_sql_report
puts
puts same ? 'SAME' : 'DIFFERENT'
puts

if !same
  sql_setup_sql_report.each.with_index { |line, i|
    line2 = seq_setup_sql_report[i]
    if line != line2
      puts "DIFF"
      puts line
      puts line2
      puts
    end
  }
end

puts "Seqel::Storage#report"
puts "====================="
puts "SQLite::Setup"
puts "-------------"
puts sql_setup_seq_report
puts
puts "Sequel::Setup"
puts "-------------"
puts seq_setup_seq_report
puts
puts sql_setup_seq_report == seq_setup_seq_report ? 'SAME' : 'DIFFERENT'
puts
