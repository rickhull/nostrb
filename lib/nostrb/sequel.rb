require 'sequel'
require 'nostrb/sqlite'

module Nostrb
  module Sequel
    class Reader
      TABLES = ['events', 'tags', 'r_events', 'r_tags']

      def self.schema_line(col, cfg)
        [col.to_s.ljust(9, ' '),
         cfg.map { |(k,v)| [k, v.inspect].join(': ') }.join("\t")
        ].join("\t")
      end

      def self.hydrate(event_row)
        Hash[ 'content' => event_row.fetch(:content),
              'kind' => event_row.fetch(:kind),
              'tags' => Nostrb.parse(event_row.fetch(:tags)),
              'pubkey' => event_row.fetch(:pubkey),
              'created_at' => event_row.fetch(:created_at),
              'id' => event_row.fetch(:id),
              'sig' => event_row.fetch(:sig), ].freeze
      end

      def self.event_clauses(filter)
        hsh = {}
        hsh[:id] = filter.ids unless filter.ids.empty?
        hsh[:pubkey] = filter.authors unless filter.authors.empty?
        hsh[:kind] = filter.kinds unless filter.kinds.empty?
        a = filter.since || Filter.ago(years: 10)
        b = filter.until || Time.now.to_i
        hsh[:created_at] = a..b
        hsh
      end

      attr_reader :filename, :db, :pragma_scalars

      def initialize(filename = SQLite::Storage::FILENAME)
        @filename = filename
        @db = ::Sequel.sqlite(filename)
        @db.transaction_mode = :immediate
        @db.pool.all_connections { |s3db|
          # set performance pragmas
          pragma = SQLite::Pragma.new(s3db)
          SQLite::Storage::PRAGMAS.each { |name, val|
            pragma.set(name, val)
          }
          # store all current pragma values (scalars only, not reports)
          @pragma_scalars ||= SQLite::Pragma::SCALAR.map { |p|
            val, enum = pragma.get(p), SQLite::Pragma::ENUM[p]
            val = format("%i (%s)", val, enum[val]) if enum
            format("%s: %s", p, val)
          }
        }
      end

      def schema(table)
        @db.schema(table).map { |a| Reader.schema_line(*a) }
      end

      def report
        lines = []
        TABLES.each { |t|
          lines << t
          lines += schema(t)
          lines << ''
        }
        lines += @pragma_scalars
        lines
      end

      def select_events_table(table = :events, filter = nil)
        if !filter.nil?
          @db[table].where(self.class.event_clauses(filter))
        else
          @db[table]
        end
      end

      def select_events(filter = nil)
        select_events_table(:events, filter)
      end

      def process_events(filter = nil)
        a = []
        select_events(filter).each { |row| a << Reader.hydrate(row) }
        a
      end

      def select_r_events(filter = nil)
        select_events_table(:r_events, filter)
      end

      def process_r_events(filter = nil)
        a = []
        select_r_events(filter).each { |row| a << Reader.hydrate(row) }
        a
      end
    end
  end
end
