require 'sqlite3'
require 'nostrb/filter'

module Nostrb
  module SQLite
    class Pragma
      ENUM = {
        'auto_vacuum' => %w[none full incremental],
        'synchronous' => %w[off normal full],
        'temp_store' => %w[default file memory],
      }

      RO = %w[data_version freelist_count page_count]
      RW = %w[application_id analysis_limit auto_vacuum automatic_index
              busy_timeout cache_size cache_spill cell_size_check
              checkpoint_fullfsync defer_foreign_keys encoding foreign_keys
              fullfsync hard_heap_limit ignore_check_constraints journal_mode
              journal_size_limit locking_mode max_page_count mmap_size
              page_size query_only read_uncommitted recursive_triggers
              reverse_unordered_selects secure_delete soft_heap_limit
              synchronous temp_store threads trusted_schema user_version
              wal_autocheckpoint]
      SCALAR = (RO + RW).sort

      #      debug: parser_trace schema_version stats vdbe_* writable_schema
      #     legacy: legacy_alter_table legacy_file_format
      # deprecated: case_sensitive_like count_changes data_store_directory
      #             default_cache_size empty_result_callbacks full_column_names
      #             short_column_names temp_store_directory

      # either no args (nil) or a single arg (symbol)
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

      # either no args (nil) or an optional single arg (symbol)
      COMMAND = {
        # checks
        foreign_key_check: :optional,  # table_name => report
        integrity_check: :optional,    # table_name | num_errors => ok
        quick_check: :optional,        # table_name | num_errors => ok
        # manipulation
        incremental_vacuum: :optional, # page_count => empty
        optimize: :optional,           # mask => empty
        shrink_memory: nil,            # empty
        wal_checkpoint: :optional, # PASSIVE | FULL | RESTART | TRUNCATE => row
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

      # just the rows
      def list(pragma, arg = nil)
        if arg.nil?
          @db.execute("PRAGMA #{pragma}")
        else
          @db.execute("PRAGMA #{pragma}(#{arg})")
        end
      end

      # include a header row
      def report(pragma, arg = nil)
        if arg.nil?
          @db.execute2("PRAGMA #{pragma}")
        else
          @db.execute2("PRAGMA #{pragma}(#{arg})")
        end
      end

      SCALAR.each { |pragma| define_method(pragma) { get(pragma) }}
      RW.each { |pragma|
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

    class Storage
      KB = 1024
      MB = KB * 1024
      GB = MB * 1024

      FILENAME = 'sqlite.tmp.db'
      CONFIG = {
        default_transaction_mode: :immediate,
      }
      SQLITE_USAGE = /\Asqlite_/

      PRAGMAS = {
        foreign_keys: true,          # enable FK constraints
        mmap_size: 128 * MB,         # enable mmap I/O, 128 MB

        # Write Ahead Log, append-only so safe for infrequent fsync
        journal_mode: 'wal',         # enable WAL, less read/write contention
        journal_size_limit: 64 * MB, # enable, 64 MB
        synchronous: 1,              # 1=normal, default, good for WAL
        wal_autocheckpoint: 1000,    # default, pages per fsync
      }

      attr_reader :filename, :db, :pragma

      def initialize(filename = FILENAME, set_pragmas: true, **kwargs)
        @filename = filename
        @db = SQLite3::Database.new(@filename, **CONFIG.merge(kwargs))
        @db.busy_handler_timeout = 5000 # 5 seconds, release GVL every ms
        @pragma = Pragma.new(@db)
        self.set_pragmas if set_pragmas
      end

      def set_pragmas
        PRAGMAS.each { |name, val| @pragma.set(name, val) }
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

      def pragma_scalars
        Pragma::SCALAR.map { |pragma|
          val, enum = @pragma.get(pragma), Pragma::ENUM[pragma]
          val = format("%i (%s)", val, enum[val]) if enum
          format("%s: %s", pragma, val)
        }
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

        lines += ['', "pragma values", '---']
        lines += self.pragma_scalars
        lines
      end
    end

    class Setup < Storage
      def read_sql(filename)
        File.read(File.join(__dir__, '..', '..', 'sql', filename)).freeze
      end

      def drop_tables
        @db.execute_batch read_sql('drop_tables.sql')
      end

      def create_tables
        @db.execute_batch read_sql('create_tables.sql')
      end

      def setup
        drop_tables
        create_tables
        report
      end
    end

    class Reader < Storage
      PRAGMAS = Storage::PRAGMAS.merge(query_only: true)

      # SELECT content, kind, tags, pubkey, created_at, id, sig
      # tags get parsed to JSON
      def self.hydrate(row)
        SignedEvent.new(content:    row[0],
                        kind:       row[1],
                        tags:       Nostrb.parse(row[2]),
                        pubkey:     row[3],
                        created_at: row[4],
                        id:         row[5],
                        sig:        row[6])
      end

      def self.event_clauses(filter)
        return 'true' if filter.nil?
        clauses = []
        if !filter.ids.empty?
          clauses << format("id IN ('%s')", filter.ids.join("','"))
        end
        if !filter.authors.empty?
          clauses << format("pubkey in ('%s')", filter.authors.join("','"))
        end
        if !filter.kinds.empty?
          clauses << format("kind in (%s)", filter.kinds.join(','))
        end
        if filter.since
          clauses << format("created_at >= %i", filter.since)
        end
        if filter.until
          clauses << format("created_at <= %i", filter.until)
        end
        clauses = clauses.join(' AND ')
        if filter.limit
          clauses = format("%s ORDER BY created_at LIMIT %i",
                           clauses, filter.limit)
        end
        clauses
      end

      # filter_tags: { 'a' => [String] }
      def self.tag_clauses(filter_tags)
        clauses = []
        filter_tags.each { |tag, values|
          clauses << format("tag = %s", tag)
          clauses << format("value in (%s)", values.join(','))
        }
        clauses.join(' AND ')
      end

      def initialize(filename = FILENAME, **kwargs)
        super(filename, **kwargs.merge(readonly: true))
      end

      #
      # Regular Events
      #

      # this query depends on a filter so cannot be efficiently prepared
      def select_events(filter = nil, table: 'events')
        @db.query format("SELECT content, kind, tags, pubkey, " +
                         "created_at, id, sig FROM %s WHERE %s",
                         table, Reader.event_clauses(filter))
      end

      # use a prepared statement to get a ResultSet
      def select_tags(event_id:, created_at:)
        @select_tags ||= @db.prepare("SELECT tag, value, json
                                      FROM tags
                                     WHERE event_id = :event_id
                                       AND created_at = :created_at")
        @select_tags.execute(event_id: event_id, created_at: created_at)
      end

      #
      # Replaceable Events
      #

      def select_r_tags(event_id:, created_at:)
        @select_r_tags ||= @db.prepare("SELECT tag, value, json
                                        FROM r_tags
                                       WHERE r_event_id = :event_id
                                         AND created_at = :created_at")
        @select_r_tags.execute(event_id: event_id, created_at: created_at)
      end
    end

    class Writer < Storage
      def self.hash(edata)
        edata.to_h.merge(tags: Nostrb.json(edata.tags))
      end

      # SignedEvent
      def add_event(edata)
        @add_event ||= @db.prepare("INSERT INTO events
                                       VALUES (:content, :kind, :tags, :pubkey,
                                               :created_at, :id, :sig)")
        @add_tag ||= @db.prepare("INSERT INTO tags
                                     VALUES (:event_id, :created_at,
                                             :tag, :value, :json)")
        @add_event.execute(Writer.hash(edata)) # insert event
        edata.tags.each { |a|                  # insert tags
          @add_tag.execute(event_id: edata.id,
                           created_at: edata.created_at,
                           tag: a[0],
                           value: a[1],
                           json: Nostrb.json(a))
        }
      end

      # add replaceable event
      def add_r_event(edata)
        @add_r_event ||=
          @db.prepare("INSERT OR REPLACE INTO r_events
                                  VALUES (:content, :kind, :tags, :d_tag,
                                          :pubkey, :created_at, :id, :sig)")
        @add_rtag ||= @db.prepare("INSERT INTO r_tags
                                      VALUES (:r_event_id, :created_at,
                                              :tag, :value, :json)")
        record = Writer.hash(edata)
        record[:d_tag] = Event.d_tag(edata.tags) || ''
        @add_r_event.execute(record) # upsert event
        edata.tags.each { |a|        # insert tags
          @add_rtag.execute(r_event_id: edata.id,
                            created_at: edata.created_at,
                            tag: a[0],
                            value: a[1],
                            json: Nostrb.json(a))
        }
      end
    end
  end
end
