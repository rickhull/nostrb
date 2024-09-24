require 'sequel'
require 'nostrb/sqlite'

module Nostrb
  module Sequel
    class Storage
      FILENAME = 'sequel.db'
      TABLES = [:events, :tags, :r_events, :r_tags]

      def self.schema_line(col, cfg)
        [col.to_s.ljust(9, ' '),
         cfg.map { |(k,v)| [k, v.inspect].join(': ') }.join("\t")
        ].join("\t")
      end

      def initialize(filename = FILENAME)
        @filename = filename
        @db = ::Sequel.connect("sqlite://#{filename}")
      end

      def setup
        Setup.new(@filename)
      end

      def reader
        Reader.new(@filename)
      end

      def writer
        Writer.new(@filename)
      end

      def schema(table)
        @db.schema(table).map { |a| Storage.schema_line(*a) }
      end

      def report
        lines = []
        TABLES.each { |t|
          lines << t
          lines += schema(t)
          lines << ''
        }
        lines
      end
    end

    class Setup < Storage
      def setup
        drop_tables
        create_tables
        report
      end

      def drop_tables
        @db.drop_table?(*TABLES)
      end

      def create_tables
        @db.create_table :events do
          text :content,    null: false
          int  :kind,       null: false
          text :tags,       null: false
          text :pubkey,     null: false
          int  :created_at, null: false, index: {
                 name: :idx_events_created_at
               }
          text :id,         null: false, primary_key: true
          text :sig,        null: false
        end

        @db.create_table :tags do
          # text :event_id, null: false # fk
          foreign_key :event_id, :events,
                      key: :id,
                      type: :text,
                      null: false,
                      on_delete: :cascade,
                      on_update: :cascade
          int  :created_at, null: false, index: { name: :idx_tags_created_at }
          text :tag,        null: false
          text :value,      null: false
          text :json,       null: false
        end

        @db.create_table :r_events do
          text :content,    null: false
          int  :kind,       null: false
          text :tags,       null: false
          text :pubkey,     null: false
          int  :created_at, null: false, index: {
                 name: :idx_r_events_created_at
               }
          text :id,         null: false
          text :sig,        null: false
          primary_key [:kind, :pubkey], name: :r_events_pk
        end

        @db.create_table :r_tags do
          int  :r_kind,     null: false
          text :r_pubkey,   null: false
          int  :created_at, null: false, index: {
                 name: :idx_r_tags_created_at
               }
          text :tag,        null: false
          text :value,      null: false
          text :json,       null: false
          foreign_key [:r_kind, :r_pubkey], :r_events,
                      key: [:kind, :pubkey],
                      on_delete: :cascade,
                      on_update: :cascade
        end
      end
    end

    class Reader < Storage
      def self.hydrate(event_row)
        Hash[ 'content' => event_row.fetch(:content),
              'kind' => event_row.fetch(:kind),
              'tags' => Nostrb.parse(event_row.fetch(:tags)),
              'pubkey' => event_row.fetch(:pubkey),
              'created_at' => event_row.fetch(:created_at),
              'id' => event_row.fetch(:id),
              'sig' => event_row.fetch(:sig), ]
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

    class Writer < Storage
      def add_event(valid)
        @db[:events].insert(valid.merge('tags' => Nostrb.json(valid['tags'])))
        valid['tags'].each { |a|
          @db[:tags].insert(event_id: valid['id'],
                            created_at: valid['created_at'],
                            tag: a[0],
                            value: a[1],
                            json: Nostrb.json(a))
        }
      end

      # use insert_conflict to replace latest event
      def add_r_event(valid)
        @db[:r_events].insert_conflict.
          insert(valid.merge('tags' => Nostrb.json(valid['tags'])))
        valid['tags'].each { |a|
          @db[:r_tags].insert_conflict.
            insert(r_kind: valid['kind'],
                   r_pubkey: valid['pubkey'],
                   created_at: valid['created_at'],
                   tag: a[0],
                   value: a[1],
                   json: Nostrb.json(a))
        }
      end
    end
  end
end
