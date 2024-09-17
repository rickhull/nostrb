require 'sqlite3'

module Nostrb
  class Storage
    class Pragma
      ENUM = {
        'auto_vacuum' => %w[none full incremental],
        'synchronous' => %w[off normal full],
        'temp_store' => %w[default file memory],
      }
      READONLY = %w[data_version freelist_count page_count]
      SCALAR =
        %w[application_id analysis_limit auto_vacuum automatic_index
           busy_timeout cache_size cache_spill cell_size_check
           checkpoint_fullfsync defer_foreign_keys encoding foreign_keys
           fullfsync hard_heap_limit ignore_check_constraints journal_mode
           journal_size_limit locking_mode max_page_count mmap_size page_size
           query_only read_uncommitted recursive_triggers
           reverse_unordered_selects secure_delete soft_heap_limit synchronous
           temp_store threads trusted_schema user_version wal_autocheckpoint]

      # debug: parser_trace schema_version stats vdbe_* writable_schema
      # legacy: legacy_alter_table legacy_file_format
      # deprecated: case_sensitive_like count_changes data_store_directory
      #             default_cache_size empty_result_callbacks full_column_names
      #             short_column_names temp_store_directory

      REPORT = {
        compile_options: nil,
        # list
        collation_list: nil,
        database_list: nil,
        function_list: nil,
        module_list: nil,
        pragma_list: nil,
        table_list: nil,
        index_list: :table_name,
        foreign_key_list: :table_name,
        # info
        index_info: :index_name,
        index_xinfo: :index_name,
        table_info: :table_name,
        table_xinfo: :table_name,
      }

      # either no args (nil) or a single arg (symbol)
      COMMAND = {
        # checks
        foreign_key_check: :optional,  # report
        integrity_check: :optional,    # ok
        quick_check: :optional,        # ok
        # manipulation
        incremental_vacuum: :optional, # empty
        optimize: :optional,           # empty
        shrink_memory: nil,            # empty
        wal_checkpoint: :optional,
      }

      def initialize(db)
        @db = db
      end

      def get(pragma)
        @db.execute("PRAGMA #{pragma}")[0][0]
      end

      def set(pragma, val)
        @db.execute("PRAGMA #{pragma} = #{val}")
        get(pragma)
      end

      def report(pragma, arg = nil)
        if arg.nil?
          @db.execute2("PRAGMA #{pragma}")
        else
          @db.execute2("PRAGMA #{pragma}(#{arg})")
        end
      end

      def list(pragma, arg = nil)
        if arg.nil?
          @db.execute("PRAGMA #{pragma}")
        else
          @db.execute("PRAGMA #{pragma}(#{arg})")
        end
      end

      READONLY.each { |pragma|
        define_method(pragma) { get(pragma) }
      }

      SCALAR.each { |pragma|
        define_method(pragma) { get(pragma) }
        define_method(pragma + '=') { |val| set(pragma, val) }
      }

      (REPORT.merge(COMMAND)).each { |pragma, arg|
        if arg.nil?
          define_method(pragma) { report(pragma) }
        elsif arg == :optional
          define_method(pragma) { |val=nil| report(pragma, val) }
        else
          define_method(pragma) { |val| report(pragma, val) }
        end
      }
    end

    KB = 1024
    MB = KB * 1024
    GB = MB * 1024

    FILENAME = 'tmp.db'
    CONFIG = {
      default_transaction_mode: :immediate,
    }

    PRAGMAS = {
      foreign_keys: true,          # enable FK constrainsts
      mmap_size: 128 * MB,         # enable mmap I/O, 128 MB

      # Write Ahead Log, append-only so safe for infrequent fsync
      journal_mode: 'wal',         # enable WAL, less read/write contention
      journal_size_limit: 64 * MB, # enable, 64 MB
      synchronous: 1,              # 1=normal, default, good for WAL
      wal_autocheckpoint: 1000,    # default, pages per fsync
    }

    SQLITE_USAGE = /\Asqlite_/

    attr_reader :filename, :db, :pragma

    def initialize(filename = FILENAME, **kwargs)
      @filename = filename
      @db = SQLite3::Database.new(@filename, **CONFIG.merge(kwargs))
      @db.busy_handler_timeout = 5000 # 5 seconds, release GVL every ms
      @pragma = Pragma.new(@db)
      self.class::PRAGMAS.each { |name, val| @pragma.set(name, val) }
    end

    # below methods all return an array of strings
    def compile_options = @pragma.list(:compile_options).map { |a| a[0] }
    def database_files = @pragma.list(:database_list).map { |a| a[2] }
    def all_table_names = @pragma.list(:table_list).map { |a| a[1] }

    def table_names
      all_table_names().select { |name| !SQLITE_USAGE.match name }
    end

    def all_index_names(table_name)
      @pragma.list(:index_list, table_name).map { |a| a[1] }
    end

    def index_names(table_name)
      all_index_names(table_name).select { |name| !SQLITE_USAGE.match name }
    end

    def report
      lines = ['compile_options', '---']
      lines += self.compile_options

      lines += ['', 'database_files', '---']
      lines += self.database_files

      lines += ['', "table_names", '---']
      tables = self.table_names
      lines += tables

      tables.each { |tbl|
        lines += ['', "table_info(#{tbl})", '---']
        lines += @pragma.table_info(tbl).map(&:inspect)

        fks = @pragma.foreign_key_list(tbl).map(&:inspect)
        if fks.length > 1
          lines += ['', "foreign_key_list(#{tbl})", '---']
          lines += fks
        end

        idxs = self.index_names(tbl)
        if !idxs.empty?
          lines += ['', "index_names(#{tbl})", '---']
          lines += idxs
        end

        idxs.each { |idx|
          lines += ['', "index_info(#{idx})", '---']
          lines += @pragma.index_info(idx).map(&:inspect)
        }
      }

      lines += ['', "pragma valuess", '---']
      Pragma::SCALAR.each { |pragma|
        val, enum = @pragma.get(pragma), Pragma::ENUM[pragma]
        val = format("%i (%s)", val, enum[val]) if enum
        lines << format("%s: %s", pragma, val)
      }

      lines
    end
  end

  class Reader < Storage
    PRAGMAS = Storage::PRAGMAS.merge(query_only: true)

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
      @db.execute "CREATE INDEX idx_events_pubkey ON events (pubkey)"
      @db.execute "CREATE INDEX idx_events_kind ON events (kind)"
      @db.execute "CREATE INDEX idx_events_created_at ON events (created_at)"

      # primary key: (event_id, tag)
      @db.execute "CREATE TABLE tags (event_id    BLOB REFERENCES
                                      events (id) ON DELETE CASCADE NOT NULL,
                                      tag         TEXT NOT NULL,
                                      value       TEXT NOT NULL,
                                      json        TEXT NOT NULL,
                     CONSTRAINT       tags_pkey   PRIMARY KEY (event_id, tag))"
      @db.execute "CREATE TABLE subscriptions (id TEXT PRIMARY KEY NOT NULL)"
    end

    def prepare
      @add_event =
        @db.prepare("INSERT INTO events
                          VALUES (:content, :kind, :pubkey,
                                  :created_at, :id, :sig)")
      @add_tag =
        @db.prepare("INSERT INTO tags " +
                    "     VALUES (:event_id, :tag, :value, :json_array)")
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
