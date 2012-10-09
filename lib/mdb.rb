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

  class MdbSargNode < FFI::Struct
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


  # file
  #extern ssize_t mdb_read_pg(MdbHandle *mdb, unsigned long pg);
  #extern ssize_t mdb_read_alt_pg(MdbHandle *mdb, unsigned long pg);
  #extern unsigned char mdb_get_byte(void *buf, int offset);
  #extern int    mdb_get_int16(void *buf, int offset);
  #extern long   mdb_get_int32(void *buf, int offset);
  #extern long   mdb_get_int32_msb(void *buf, int offset);
  #extern float  mdb_get_single(void *buf, int offset);
  #extern double mdb_get_double(void *buf, int offset);
  #extern unsigned char mdb_pg_get_byte(MdbHandle *mdb, int offset);
  #extern int    mdb_pg_get_int16(MdbHandle *mdb, int offset);
  #extern long   mdb_pg_get_int32(MdbHandle *mdb, int offset);
  #extern float  mdb_pg_get_single(MdbHandle *mdb, int offset);
  #extern double mdb_pg_get_double(MdbHandle *mdb, int offset);
  attach_function :mdb_open, [:string, :file_flags], MdbHandle.by_ref
  attach_function :mdb_close, [MdbTableDef], :void
  #extern MdbHandle *mdb_clone_handle(MdbHandle *mdb);
  #extern void mdb_swap_pgbuf(MdbHandle *mdb);

  # catalog
  #extern void mdb_free_catalog(MdbHandle *mdb);
  #extern GPtrArray *mdb_read_catalog(MdbHandle *mdb, int obj_type);
  #MdbCatalogEntry *mdb_get_catalogentry_by_name(MdbHandle *mdb, const gchar* name);
  #extern void mdb_dump_catalog(MdbHandle *mdb, int obj_type);
  #extern char *mdb_get_objtype_string(int obj_type);

  # table
  #extern MdbTableDef *mdb_alloc_tabledef(MdbCatalogEntry *entry);
  attach_function :mdb_free_tabledef, [MdbTableDef], :void
  #extern MdbTableDef *mdb_read_table(MdbCatalogEntry *entry);
  attach_function :mdb_read_table_by_name, [MdbHandle, :string, :obj_type], MdbTableDef.by_ref
  #extern void mdb_append_column(GPtrArray *columns, MdbColumn *in_col);
  #extern void mdb_free_columns(GPtrArray *columns);
  attach_function :mdb_read_columns, [MdbTableDef], :pointer
  #extern void mdb_table_dump(MdbCatalogEntry *entry);
  #extern guint8 read_pg_if_8(MdbHandle *mdb, int *cur_pos);
  #extern guint16 read_pg_if_16(MdbHandle *mdb, int *cur_pos);
  #extern guint32 read_pg_if_32(MdbHandle *mdb, int *cur_pos);
  #extern void *read_pg_if_n(MdbHandle *mdb, void *buf, int *cur_pos, size_t len);
  #extern int mdb_is_user_table(MdbCatalogEntry *entry);
  #extern int mdb_is_system_table(MdbCatalogEntry *entry);
  #extern const char *mdb_table_get_prop(const MdbTableDef *table, const gchar *key);
  #extern const char *mdb_col_get_prop(const MdbColumn *col, const gchar *key);

  #/* data.c */
  #extern int mdb_bind_column_by_name(MdbTableDef *table, gchar *col_name, void *bind_ptr, int *len_ptr);
  #extern void mdb_data_dump(MdbTableDef *table);
  #extern void mdb_date_to_tm(double td, struct tm *t);
  attach_function :mdb_bind_column, [MdbTableDef, :int, :pointer, :pointer], :void
  attach_function :mdb_rewind_table, [MdbTableDef], :int
  attach_function :mdb_fetch_row, [MdbTableDef], :int
  #extern int mdb_is_fixed_col(MdbColumn *col);
  #extern char *mdb_col_to_string(MdbHandle *mdb, void *buf, int start, int datatype, int size);
  #extern int mdb_find_pg_row(MdbHandle *mdb, int pg_row, void **buf, int *off, size_t *len);
  #extern int mdb_find_row(MdbHandle *mdb, int row, int *start, size_t *len);
  #extern int mdb_find_end_of_row(MdbHandle *mdb, int row);
  #extern int mdb_col_fixed_size(MdbColumn *col);
  #extern int mdb_col_disp_size(MdbColumn *col);
  #extern size_t mdb_ole_read_next(MdbHandle *mdb, MdbColumn *col, void *ole_ptr);
  #extern size_t mdb_ole_read(MdbHandle *mdb, MdbColumn *col, void *ole_ptr, int chunk_size);
  attach_function :mdb_ole_read_full, [MdbHandle, MdbColumn, :pointer], :string
  attach_function :mdb_set_date_fmt, [:string], :void
  #extern int mdb_read_row(MdbTableDef *table, unsigned int row);

  #/* dump.c */
  #extern void mdb_buffer_dump(const void *buf, int start, size_t len);

  #/* backend.c */
  #extern char* __attribute__((deprecated)) mdb_get_coltype_string(MdbBackend *backend, int col_type);
  #extern int __attribute__((deprecated)) mdb_coltype_takes_length(MdbBackend *backend, int col_type);
  #extern const MdbBackendType* mdb_get_colbacktype(const MdbColumn *col);
  #extern const char* mdb_get_colbacktype_string(const MdbColumn *col);
  #extern int mdb_colbacktype_takes_length(const MdbColumn *col);
  #extern void __attribute__((deprecated)) mdb_init_backends();
  #extern void mdb_register_backend(char *backend_name, guint32 capabilities, MdbBackendType *backend_type, MdbBackendType *type_shortdate, MdbBackendType *type_autonum, const char *short_now, const char *long_now, const char *charset_statement, const char *drop_statement, const char *constaint_not_empty_statement, const char *column_comment_statement, const char *table_comment_statement, gchar* (*quote_schema_name)(const gchar*, const gchar*));
  #extern void __attribute__((deprecated)) mdb_remove_backends();
  attach_function :mdb_set_default_backend, [MdbHandle, :string], :int
  #extern void mdb_print_schema(MdbHandle *mdb, FILE *outfile, char *tabname, char *dbnamespace, guint32 export_options);

  #/* sargs.c */
  #extern int mdb_test_sargs(MdbTableDef *table, MdbField *fields, int num_fields);
  #extern int mdb_test_sarg(MdbHandle *mdb, MdbColumn *col, MdbSargNode *node, MdbField *field);
  #extern void mdb_sql_walk_tree(MdbSargNode *node, MdbSargTreeFunc func, gpointer data);
  #extern int mdb_find_indexable_sargs(MdbSargNode *node, gpointer data);
  #extern int mdb_add_sarg_by_name(MdbTableDef *table, char *colname, MdbSarg *in_sarg);
  #extern int mdb_test_string(MdbSargNode *node, char *s);
  #extern int mdb_test_int(MdbSargNode *node, gint32 i);
  #extern int mdb_add_sarg(MdbColumn *col, MdbSarg *in_sarg);

  #/* index.c */
  #extern GPtrArray *mdb_read_indices(MdbTableDef *table);
  #extern void mdb_index_dump(MdbTableDef *table, MdbIndex *idx);
  #extern void mdb_index_scan_free(MdbTableDef *table);
  #extern int mdb_index_find_next_on_page(MdbHandle *mdb, MdbIndexPage *ipg);
  #extern int mdb_index_find_next(MdbHandle *mdb, MdbIndex *idx, MdbIndexChain *chain, guint32 *pg, guint16 *row);
  #extern void mdb_index_hash_text(char *text, char *hash);
  #extern void mdb_index_scan_init(MdbHandle *mdb, MdbTableDef *table);
  #extern int mdb_index_find_row(MdbHandle *mdb, MdbIndex *idx, MdbIndexChain *chain, guint32 pg, guint16 row);
  #extern void mdb_index_swap_n(unsigned char *src, int sz, unsigned char *dest);
  #extern void mdb_free_indices(GPtrArray *indices);
  #void mdb_index_page_reset(MdbIndexPage *ipg);
  #extern int mdb_index_pack_bitmap(MdbHandle *mdb, MdbIndexPage *ipg);

  # stats
  attach_function :mdb_stats_on, [MdbHandle], :void
  attach_function :mdb_stats_off, [MdbHandle], :void
  attach_function :mdb_dump_stats, [MdbHandle], :void

  #/* like.c */
  #extern int mdb_like_cmp(char *s, char *r);

  #/* write.c */
  #extern void mdb_put_int16(void *buf, guint32 offset, guint32 value);
  #extern void mdb_put_int32(void *buf, guint32 offset, guint32 value);
  #extern void mdb_put_int32_msb(void *buf, guint32 offset, guint32 value);
  #extern int mdb_crack_row(MdbTableDef *table, int row_start, int row_end, MdbField *fields);
  #extern guint16 mdb_add_row_to_pg(MdbTableDef *table, unsigned char *row_buffer, int new_row_size);
  #extern int mdb_update_index(MdbTableDef *table, MdbIndex *idx, unsigned int num_fields, MdbField *fields, guint32 pgnum, guint16 rownum);
  #extern int mdb_insert_row(MdbTableDef *table, int num_fields, MdbField *fields);
  #extern int mdb_pack_row(MdbTableDef *table, unsigned char *row_buffer, unsigned int num_fields, MdbField *fields);
  #extern int mdb_replace_row(MdbTableDef *table, int row, void *new_row, int new_row_size);
  #extern int mdb_pg_get_freespace(MdbHandle *mdb);
  #extern int mdb_update_row(MdbTableDef *table);
  #extern void *mdb_new_data_pg(MdbCatalogEntry *entry);

  #/* map.c */
  #extern guint32 mdb_map_find_next_freepage(MdbTableDef *table, int row_size);
  #extern gint32 mdb_map_find_next(MdbHandle *mdb, unsigned char *map, unsigned int map_sz, guint32 start_pg);

  #/* props.c */
  #extern void mdb_free_props(MdbProperties *props);
  #extern void mdb_dump_props(MdbProperties *props, FILE *outfile, int show_name);
  #extern GArray* mdb_kkd_to_props(MdbHandle *mdb, void *kkd, size_t len);

  #/* worktable.c */
  #extern MdbTableDef *mdb_create_temp_table(MdbHandle *mdb, char *name);
  #extern void mdb_temp_table_add_col(MdbTableDef *table, MdbColumn *col);
  #extern void mdb_fill_temp_col(MdbColumn *tcol, char *col_name, int col_size, int col_type, int is_fixed);
  #extern void mdb_fill_temp_field(MdbField *field, void *value, int siz, int is_fixed, int is_null, int start, int column);
  #extern void mdb_temp_columns_end(MdbTableDef *table);

  ## options.c 
  #extern int mdb_get_option(unsigned long optnum);
  #extern void mdb_debug(int klass, char *fmt, ...);

  # iconv
  #extern int mdb_unicode2ascii(MdbHandle *mdb, char *src, size_t slen, char *dest, size_t dlen);
  #extern int mdb_ascii2unicode(MdbHandle *mdb, char *src, size_t slen, char *dest, size_t dlen);
  #extern void mdb_iconv_init(MdbHandle *mdb);
  #extern void mdb_iconv_close(MdbHandle *mdb);
  #extern const char* mdb_target_charset(MdbHandle *mdb);
end
