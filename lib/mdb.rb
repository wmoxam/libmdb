require 'ffi'

module MDB
  extend FFI::Library
  ffi_lib "mdb"

  BIND_SIZE = 16384
  MAX_IDX_COLS = 10
  MAX_INDEX_DEPTH = 10
  MAX_OBJ_NAME = 256
  PGSIZE = 4096

  enum :file_flags, [:no_flags, 0x00, :writeable, 0x01]

  enum :obj_type, [:form, 0, :table, :macro, :system_table, :report, :query, :linked_table, :module,
       :relationship, :unknown_09, :unknown_0a, :database_property, :any, -1]

  enum :strategy, [:table_scan, :leaf_scan, :index_scan]

  enum :column_type, [:bool, 0x01, :byte, 0x02, :int, 0x03, :longint, 0x04, :money, 0x05,
       :float, 0x06, :double, 0x07, :datetime, 0x08, :binary, 0x09,
       :text, 0x0a, :ole, 0x0b, :memo, 0x0c, :repid, 0x0f,
       :numeric, 0x10, :complex, 0x12]

  callback :quote_schema_name, [:string, :string], :string

  class MdbAny < FFI::Union
    layout  :i, :int,
            :d, :double,
            :s, [:char, 256]
  end

  class PtrArray < FFI::Struct
    layout  :pdata, :pointer,
            :len, :uint
  end

  class MdbBackendType < FFI::Struct
    layout  :name, :string,
            :needs_length, :uchar,
            :needs_scale, :uchar,
            :needs_quotes, :uchar
  end

  class MdbBackend < FFI::Struct
    layout  :capabilities, :uint32,
            :types_table, MdbBackendType,
            :type_shortdate, MdbBackendType,
            :type_autonum, MdbBackendType,
            :short_now, :string,
            :long_now, :string,
            :charset_statement, :string,
            :drop_statement, :string,
            :constaint_not_empty_statement, :string,
            :column_comment_statement, :string,
            :table_comment_statement, :string,
            :quote_schema_name, :string
  end

  class MdbStatistics < FFI::Struct
    layout  :collect, :bool,
            :pg_reads, :ulong
  end

  class MdbFile < FFI::Struct
    layout  :fd, :int,
            :writable, :bool,
            :filename, :string,
            :jet_version, :uint32,
            :db_key, :uint32,
            :db_passwd, [:char, 14],
            :default_backend, MdbBackend,
            :backend_name, :string,
            :stats, MdbStatistics,
            :map_sz, :int,
            :free_map, :pointer,
            :refs, :int
  end

  class MdbFormatConstants < FFI::Struct
    layout  :pg_size, :size_t,
            :row_count_offset, :uint16,
            :tab_num_rows_offset, :uint16,
            :tab_num_cols_offset, :uint16,
            :tab_num_idxs_offset, :uint16,
            :tab_num_ridxs_offset, :uint16,
            :tab_usage_map_offset, :uint16,
            :tab_first_dpg_offset, :uint16,
            :tab_cols_start_offset, :uint16,
            :tab_ridx_entry_size, :uint16,
            :col_flags_offset, :uint16,
            :col_size_offset, :uint16,
            :col_num_offset, :uint16,
            :tab_col_entry_size, :uint16,
            :tab_free_map_offset, :uint16,
            :tab_col_offset_var, :uint16,
            :tab_col_offset_fixed, :uint16,
            :tab_row_col_num_offset, :uint16
  end

  class MdbHandle < FFI::Struct
    layout  :f, MdbFile,
	          :cur_pg, :uint32,
	          :row_num, :uint16,
	          :cur_pos, :uint,
	          :pg_buf, [:uchar, PGSIZE],
	          :alt_pg_buf, [:uchar, PGSIZE],
	          :num_catalog, :uint,
	        	:catalog, PtrArray,
		        :default_backend, MdbBackend,
	          :backend_name, :string,
            :fmt, MdbFormatConstants,
	          :stats, MdbStatistics
  end

  class MdbCatalogEntry < FFI::Struct
    layout  :mdb, MdbHandle,
            :object_name, [:char, MAX_OBJ_NAME+1],
            :object_type, :int,
            :table_pg, :ulong,
            :props, :pointer, # PtrArray,
            :columns, :pointer, # PtrArray,
            :flags, :int
  end

  class MdbProperties < FFI::Struct
    layout  :name, :string,
            :hash, :pointer   # GHashTable, not implementing for now
  end

  class MdbColumn < FFI::Struct
    layout  :table, :pointer, #MdbTableDef,
            :name, [:char, MAX_OBJ_NAME+1],
            :col_type, :column_type,
            :col_size, :int,
            :bind_ptr, :pointer, # void *
            :len_ptr, :pointer, # int *
            :properties, :pointer, #GHashTable
            :num_sargs, :uint,
            :sargs, :pointer, #PtrArray,
            :idx_sarg_cache, :pointer, #PtrArray,
            :is_fixed, :uchar,
            :query_order, :int,
            :col_num, :int,
            :cur_value_start, :int,
            :cur_value_len, :int,
            :cur_blob_pg_row, :uint32,
            :chunk_size, :int,
            :col_prec, :int,
            :col_scale, :int,
            :is_long_auto, :uchar,
            :is_uuid_auto, :uchar,
            :props, :pointer, #MdbProperties,
            :fixed_offset, :int,
            :var_col_num, :uint,
            :row_col_num, :int
  end

  class MdbSargNode < FFI::Struct # The real deal
    layout  :op, :int,
            :col, MdbColumn,
            :value, MdbAny,
            :parent, :pointer,
            :left, :pointer,
            :right, :pointer
  end

  class MdbIndex < FFI::Struct
    layout  :index_num, :int,
            :name, [:char, MAX_OBJ_NAME+1],
            :index_type, :uchar,
            :first_pg, :uint32,
            :num_rows, :int,
            :num_keys, :uint,
            :key_col_num, [:short, MAX_IDX_COLS],
            :key_col_order, [:uchar, MAX_IDX_COLS],
            :flags, :uchar,
            :table, :pointer
  end

  class MdbIndexPage < FFI::Struct
    layout  :pg, :uint32,
            :start_pos, :int,
            :offset, :int,
            :len, :int,
            :idx_starts, [:uint16, 2000],
            :cache_value, [:uchar, 256]
  end

  class MdbIndexChain < FFI::Struct
    layout  :cur_depth, :int,
            :last_leaf_found, :uint32,
            :clean_up_mode, :int,
            :pages, [MdbIndexPage, MAX_INDEX_DEPTH]
  end

  class MdbTableDef < FFI::Struct  # The real deal
    layout  :entry, :pointer, #MdbCatalogEntry,
            :name, [:char, MAX_OBJ_NAME+1],
            :num_cols, :uint,
            :columns, :pointer,
            :num_rows, :uint,
            :index_start, :int,
            :num_real_idxs, :uint,
            :num_idxs, :uint,
            :indices, :pointer, #PtrArray,
            :first_data_pg, :uint32,
            :cur_pg_num, :uint32,
            :cur_phys_pg, :uint32,
            :cur_row, :uint,
            :noskip_del, :int,
            :map_base_pg, :uint32,
            :map_sz, :size_t,
            :usage_map, :pointer,  # unsigned char *
            :freemap_base_pg, :uint32,
            :freemap_sz, :size_t,
            :free_usage_map, :pointer, # unsigned char *
            :sarg_tree, :pointer, # MdbSargNode,
            :strategy, :strategy,
            :scan_idx, :pointer, # MdbIndex,
            :mdbidx, :pointer, # MdbHandle,
            :chain, :pointer, # MdbIndexChain,
            :props, :pointer, # MdbProperties,
            :num_var_cols, :uint,
            :is_temp_table, :uint,
            :temp_table_pages, :pointer # PtrArray
  end

  class BoundValue < FFI::Struct
    layout :value, [:char, 256]
  end

  class BoundLength < FFI::Struct
    layout :len, :uint
  end


  attach_function :mdb_open, [:string, :file_flags], MdbHandle.by_ref
  attach_function :mdb_read_table_by_name, [MdbHandle, :string, :obj_type], MdbTableDef.by_ref
  attach_function :mdb_read_columns, [MdbTableDef], :pointer
  attach_function :mdb_rewind_table, [MdbTableDef], :int
  attach_function :mdb_bind_column, [MdbTableDef, :int, :pointer, :pointer], :void
  attach_function :mdb_fetch_row, [MdbTableDef], :int
  attach_function :mdb_free_tabledef, [MdbTableDef], :void
  attach_function :mdb_close, [MdbTableDef], :void
end
