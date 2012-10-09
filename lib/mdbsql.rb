require 'ffi'
require "#{File.dirname(__FILE__)}/mdb"

module MDB
  module SQL
    extend FFI::Library
    ffi_lib "mdbsql"

    class MdbSQL < FFI::Struct
      layout  :mdb, :pointer,
            :all_columns, :int,
            :num_columns, :uint,
            :columns, :pointer, # PtrArray,
            :num_tables, :uint,
            :tables, :pointer, # PtrArray,
            :cur_table, :pointer, # MdbTableDef
            :sarg_tree, :pointer, # MdbSargNode
            :sarg_stack, :pointer, # GList
            :bound_values, [:pointer, 256],
            :kludge_ttable_pg, :pointer,
            :max_rows, :int,
            :error_msg, [:char, 256]
    end

    class MdbSQLColumn < FFI::Struct
      layout    :name, :string,
                :disp_size, :int,
                :bind_addr, :pointer,  # void*
                :bind_type, :int,
                :bind_len, :pointer, # int
                :bind_max, :int
    end

    #typedef struct {
    #	char *name;
    #	char *alias;
    #} MdbSQLTable;

    #typedef struct {
    #	char *col_name;
    #	MdbSarg *sarg;
    #} MdbSQLSarg;

    #extern char *g_input_ptr;

    ##undef YY_INPUT
    ##define YY_INPUT(b, r, ms) (r = mdb_sql_yyinput(b, ms));

    def self.mdb_sql_has_error?(sql)
      sql[:error_msg][0] > 0
    end

    ##define mdb_sql_last_error(sql) ((sql)->error_msg)

    #void mdb_sql_error(MdbSQL* sql, char *fmt, ...);
    #extern MdbSQL *_mdb_sql(MdbSQL *sql);
    attach_function :mdb_sql_init, [], MdbSQL.by_ref
    #extern MdbSQLSarg *mdb_sql_alloc_sarg();
    attach_function :mdb_sql_open, [MdbSQL, :string], MdbHandle.by_ref
    #extern int mdb_sql_add_sarg(MdbSQL *sql, char *col_name, int op, char *constant);
    #extern void mdb_sql_all_columns(MdbSQL *sql);
    #extern int mdb_sql_add_column(MdbSQL *sql, char *column_name);
    #extern int mdb_sql_add_table(MdbSQL *sql, char *table_name);
    attach_function :mdb_sql_dump, [MdbSQL], :void
    attach_function :mdb_sql_exit, [MdbSQL], :void
    attach_function :mdb_sql_reset, [MdbSQL], :void
    #extern void mdb_sql_listtables(MdbSQL *sql);
    #extern void mdb_sql_select(MdbSQL *sql);
    attach_function :mdb_sql_dump_node, [MDB::MdbSargNode, :int], :void
    #extern void mdb_sql_close(MdbSQL *sql);
    #extern void mdb_sql_add_or(MdbSQL *sql);
    #extern void mdb_sql_add_and(MdbSQL *sql);
    #extern void mdb_sql_add_not(MdbSQL *sql);
    #extern void mdb_sql_describe_table(MdbSQL *sql);
    attach_function :mdb_sql_run_query, [MdbSQL, :string], MdbSQL.by_ref
    #extern void mdb_sql_set_maxrow(MdbSQL *sql, int maxrow);
    #extern int mdb_sql_eval_expr(MdbSQL *sql, char *const1, int op, char *const2);
    attach_function :mdb_sql_bind_all, [MdbSQL], :void
    #extern int mdb_sql_fetch_row(MdbSQL *sql, MdbTableDef *table);
    #extern int mdb_sql_add_temp_col(MdbSQL *sql, MdbTableDef *ttable, int col_num, char *name, int col_type, int col_size, int is_fixed);
    #extern void mdb_sql_bind_column(MdbSQL *sql, int colnum, void *varaddr, int *len_ptr);
  end
end
