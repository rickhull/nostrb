require 'sqlite3'

module Nostrb
  class Storage
    KB = 1024
    MB = KB * 1024
    GB = MB * 1024

    FILENAME = 'nostrb.db'
    CONFIG = {
      results_as_hash: true,
      default_transaction_mode: :immediate,
    }

    attr_reader :filename, :db

    def initialize(filename = FILENAME, **kwargs)
      @filename = filename
      @db = SQLite3::Database.new(@filename, **CONFIG.merge(kwargs))
    end

    def set_pragmas
      @db.journal_mode = 'wal'         # write ahead log, less contention
      @db.synchronous = 1              # normal, default, good for WAL
      @db.wal_autocheckpoint = 200     # default 1000, for pages per fsync
      @db.mmap_size = 128 * MB         # enable, 128 MB
      @db.journal_size_limit = 64 * MB # enable, 64 MB
      @db.foreign_keys = true          # enable foreign key constraints
      @db.busy_handler_timeout = 5000  # 5 seconds, release GVL while waiting
    end

    def report
      auto_vacuum = %w[none full incremental]
      synchronous = %w[off normal full]
      temp_store = %w[default file memory]
      wal_checkpoint = %w[passive full restart truncate]

      lines = ["table_info", '---']
      %w[events subscriptions tags].each { |tbl|
        str = @db.table_info(tbl).inject("") { |memo, hsh|
          col = format("%s:%s", hsh["name"], hsh["type"])
          if hsh["pk"] > 0
            col = format("%s:pk%i", col, hsh["pk"])
          elsif hsh["notnull"] == 1
            col = format("%s:notnull", col)
          end
          memo + format(" %s", col)
        }
        lines << format("%s:%s", tbl, str)
      }

      lines += ['', "foreign_key_list", '---']
      lines += @db.foreign_key_list('tags').map { |h| format("tags: %s", h) }

      lines += ['', "index_list", '---']
      lines += @db.index_list('events')

      lines += ['', "index_info", '---']
      lines << "created_at_idx: #{@db.index_info('created_at_idx').first}"
      lines << "kind_idx: #{@db.index_info('kind_idx').first}"
      lines << "pubkey_idx: #{@db.index_info('pubkey_idx').first}"

      lines += ['', "pragmas", '---']
      %w[automatic_index auto_vacuum cache_size cache_spill
         checkpoint_fullfsync encoding foreign_keys freelist_count
         fullfsync journal_mode journal_size_limit locking_mode
         max_page_count mmap_size page_count page_size read_uncommitted
         recursive_triggers reverse_unordered_selects secure_delete
         soft_heap_limit synchronous temp_store threads
         wal_autocheckpoint wal_checkpoint].each { |pragma|
        val = case pragma
              when 'auto_vacuum'
                int = @db.auto_vacuum
                format("%i (%s)", int, auto_vacuum[int])
              when 'synchronous'
                int = @db.synchronous
                format("%i (%s)", int, synchronous[int])
              when 'temp_store'
                int = @db.temp_store
                format("%i (%s)", int, temp_store[int])
              when 'wal_checkpoint'
                int = @db.wal_checkpoint
                format("%i (%s)", int, wal_checkpoint[int])
              else
                @db.send(pragma)
              end
        lines << format("%s: %s", pragma, val)
      }

      # commands %w[busy_timeout integrity_check optimize quick_check
      # shrink_memory]

      lines
    end
  end

  class Reader < Storage
    def initialize(filename = FILENAME)
      super(filename, readonly: true)
      set_pragmas()
      @select_events = @db.prepare("SELECT content, kind, pubkey,
                                           created_at, id, sig
                                      FROM events")
      @select_tags = @db.prepare("SELECT tag, value, json
                                    FROM tags
                                   WHERE event_id = :event_id")
    end

    def set_pragmas
      super()
      @db.query_only = true
    end

    def select_events
      @select_events.execute
    end

    def select_tags(event_id)
      @select_tags.execute(event_id: event_id)
    end

    def add_tags(hash)
      tags = select_tags(hash.fetch("id"))
      hash["tags"] = []
      tags.each { |h|
        hash["tags"] << Nostrb.parse(h.fetch("json"))
      }
      hash
    end
  end

  class Writer < Storage
    def initialize(filename = FILENAME)
      super(filename)
      set_pragmas()
      @add_event =
        @db.prepare("INSERT INTO events
                          VALUES (:content, :kind, :pubkey,
                                  :created_at, :id, :sig)")
      @add_tag =
        @db.prepare("INSERT INTO tags " +
                    "     VALUES (:event_id, :tag, :value, :json_array)")
    end

    def drop_tables
      %w[events tags subscriptions].each { |tbl|
        @db.execute "DROP TABLE #{tbl}" rescue nil
      }
    end

    def create_tables
      self.drop_tables
      @db.execute "CREATE TABLE events (content TEXT NOT NULL,
                                        kind INTEGER NOT NULL,
                                        pubkey BLOB NOT NULL,
                                        created_at INTEGER NOT NULL,
                                        id BLOB PRIMARY KEY NOT NULL,
                                        sig BLOB NOT NULL)"

      # create index on pubkey, kind, created_at
      @db.execute "CREATE INDEX pubkey_idx ON events (pubkey)"
      @db.execute "CREATE INDEX kind_idx ON events (kind)"
      @db.execute "CREATE INDEX created_at_idx ON events (created_at)"

      # primary key: (event_id, tag)
      @db.execute "CREATE TABLE tags (event_id    BLOB REFERENCES
                                      events (id) ON DELETE CASCADE NOT NULL,
                                      tag         TEXT NOT NULL,
                                      value       TEXT NOT NULL,
                                      json        TEXT NOT NULL,
                     CONSTRAINT       tags_pkey   PRIMARY KEY (event_id, tag))"
      @db.execute "CREATE TABLE subscriptions (id TEXT PRIMARY KEY NOT NULL)"
    end

    # a valid hash, as returned from SignedEvent.validate!
    def add_event(valid)
      tags = valid.delete("tags")
      @add_event.execute(valid)
      tags.each { |a|
        @add_tag.execute(event_id: valid.id,
                         tag: a[0],
                         value: a[1],
                         json: Nostrb.json(a))
      }
    end
  end
end
