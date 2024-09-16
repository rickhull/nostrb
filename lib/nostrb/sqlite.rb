require 'sqlite3'

module Nostrb
  class Storage
    KB = 1024
    MB = KB * 1024
    GB = MB * 1024

    FILENAME = 'tmp.db'
    CONFIG = {
      default_transaction_mode: :immediate,
      results_as_hash: true,
    }

    # busy_timeout and ignore_check_constrants are added dynamically
    PRAGMAS =
      %w[application_id auto_vacuum automatic_index busy_timeout
         cache_size cache_spill cell_size_check checkpoint_fullfsync
         data_version defer_foreign_keys encoding foreign_keys
         freelist_count fullfsync ignore_check_constraints journal_mode
         journal_size_limit locking_mode max_page_count mmap_size page_count
         page_size query_only read_uncommitted recursive_triggers
         reverse_unordered_selects secure_delete soft_heap_limit synchronous
         temp_store threads user_version wal_autocheckpoint wal_checkpoint]

    # debug: parser_trace schema_version stats vdbe_* writable_schema
    # legacy: legacy_alter_table legacy_file_format
    # deprecated: case_sensitive_like count_changes data_store_directory
    #             default_cache_size empty_result_callbacks full_column_names
    #             short_column_names temp_store_directory
    # assign only: busy_timeout= ignore_check_constraints=
    # unsupported: analysis_limit hard_heap_limit trusted_schema

    # either no args (nil) or a single arg (symbol)
    COMMAND_PRAGMAS = {
      collation_list: nil,
      compile_options: nil,
      database_list: nil,
      foreign_key_check: nil,
      function_list: nil,     # added dynamically
      integrity_check: nil,
      module_list: nil,       # added dynamically
      optimize: nil,          # added dynamically
      pragma_list: nil,       # added dynamically
      quick_check: nil,
      shrink_memory: nil,
      table_list: nil,        # added dynamically
      foreign_key_list: :table_name,
      incremental_vacuum: :num_pages,
      index_info: :index_name,
      index_list: :table_name,
      index_xinfo: :index_name,
      table_info: :table_name,
      table_xinfo: :table_name, # added dynamically
    }

    # add these below
    DYNAMIC_PRAGMAS = {
      busy_timeout: :scalar,
      ignore_check_constraints: :scalar,
      function_list: nil,
      module_list: nil,
      optimize: nil,
      pragma_list: nil,
      table_list: nil,
      table_xinfo: :table_name,
    }

    DYNAMIC_PRAGMAS.each { |name, val|
      if val
        if val == :scalar
          SQLite3::Database.define_method(name) {
            execute("PRAGMA #{name}").first.values.first
          }
        else
          SQLite3::Database.define_method(name) { |arg|
            execute("PRAGMA #{name}(#{arg})")
          }
        end
      else
        SQLite3::Database.define_method(name) {
          execute("PRAGMA #{name}")
        }
      end
    }

    SET_PRAGMAS = {
      foreign_keys: true,          # enable FK constrainsts
      mmap_size: 128 * MB,         # enable mmap I/O, 128 MB

      # Write Ahead Log, append-only so safe for infrequent fsync
      journal_mode: 'wal',         # enable WAL, less read/write contention
      journal_size_limit: 64 * MB, # enable, 64 MB
      synchronous: 1,              # 1=normal, default, good for WAL
      wal_autocheckpoint: 1000,    # default, pages per fsync
    }

    attr_reader :filename, :db

    def initialize(filename = FILENAME, **kwargs)
      @filename = filename
      @db = SQLite3::Database.new(@filename, **CONFIG.merge(kwargs))
      @db.busy_handler_timeout = 5000 # 5 seconds, release GVL every ms
      self.class::SET_PRAGMAS.each { |name, val| @db.send("#{name}=", val) }
    end

    def compile_options
      @db.compile_options.map { |h| h['compile_options'] }
    end

    def report
      auto_vacuum = %w[none full incremental]
      synchronous = %w[off normal full]
      temp_store = %w[default file memory]
      wal_checkpoint = %w[passive full restart truncate]

      lines = ["compile_options", '---']
      lines += self.compile_options

      lines += ['', "database_list", '---']
      lines += @db.database_list

      lines += ['', "table_list", '---']
      tables = @db.table_list
      lines += tables

      lines += ['', "table_info", '---']
      my_tables = []
      tables.each { |hsh|
        tbl = hsh.fetch('name')
        next if tbl.match /sqlite_(?:temp_)?schema/
        my_tables << tbl
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
      my_tables.each { |tbl|
        lines += @db.foreign_key_list(tbl).map { |h|
          format("%s: %s", tbl, h)
        }
      }

      lines += ['', "index_list", '---']
      my_idx = []
      my_tables.each { |tbl|
        lines += @db.index_list(tbl).map { |h|
          if !h.fetch("name").match /sqlite_autoindex/
            my_idx << h["name"]
          end
          format("%s: %s", tbl, h)
        }
      }

      lines += ['', "index_info", '---']
      my_idx.each { |idx|
        lines += @db.index_info(idx).map { |h|
          format("%s: %s", idx, h)
        }
      }

      lines += ['', "pragmas", '---']
      PRAGMAS.each { |pragma|
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
      lines
    end
  end

  class Reader < Storage
    SET_PRAGMAS = Storage::SET_PRAGMAS.merge(query_only: true)

    def initialize(filename = FILENAME, **kwargs)
      super(filename, **kwargs.merge(readonly: true))
    end

    def prepare
      @select_events = @db.prepare("SELECT content, kind, pubkey,
                                           created_at, id, sig
                                      FROM events")
      @select_tags = @db.prepare("SELECT tag, value, json
                                    FROM tags
                                   WHERE event_id = :event_id")
    end

    def select_events
      self.prepare unless @select_events
      @select_events.execute
    end

    def select_tags(event_id)
      self.prepare unless @select_tags
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
    def prepare
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
        @db.execute "DROP TABLE IF EXISTS #{tbl}" rescue nil
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
      self.prepare unless @add_tag
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
