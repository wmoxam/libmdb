# Ruby port of mdb-export
# https://github.com/brianb/mdbtools/blob/master/src/util/mdb-export.c

require 'getoptlong'
require 'rubygems'
require '../lib/mdb'

MDB::BIND_SIZE = 200000

def is_quote_type?(x)
  [:text, :ole, :memo, :datetime, :binary, :repid].include?(x)
end

def is_binary_type?(x)
  [:ole, :binary, :repid].include?(x)
end

def print_col(col_val, quote_text, col_type, quote_char, escape_char)
  value = col_val[:value].to_s

	if quote_text && is_quote_type?(col_type)
		print quote_char
    value.gsub!(escape_char, escape_char * 2) unless escape_char.nil?
    value.gsub!(quote_char, escape_char.to_s + quote_char.to_s) unless quote_char.nil?
    print value
		print quote_char
	else
		print col_val[:value].to_s
  end
end

def escapes(s)
  encode = false
  encoded = ""

  s.to_s.split("").each do |char|
		if (encode)
			case char
			when 'n'
        encoded << '\n'
        break
			when 't'
        encoded << '\t'
        break
			when 'r'
        encoded << '\r'
        break
      else
        encoded << "\\#{char}"
        break
      end
			encode = false
		elsif char == '\\'
			encode = true
		else
			encoded << s
		end
	end
  encoded
end

opts = GetoptLong.new(
  [ '-H', GetoptLong::NO_ARGUMENT ],
  [ '-d', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-R', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-I', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-D', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-q', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-X', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-N', GetoptLong::REQUIRED_ARGUMENT ]
)

@header_row = true
@quote_text = true
@quote_char = "\""
@delimiter = ","
@row_delimiter = "\n"
@escape_char = nil
@namespace = nil
@insert_dialect = nil

opts.each do |opt, arg|
  case opt
  when '-H'
    @header_row = false
    break
	when '-Q'
		@quote_text = false
		break
	when '-q'
		@quote_char = arg
		break
	when '-d'
		@delimiter = escapes(arg)
		break
	when '-R'
		@row_delimiter = escapes(arg)
		break
	when '-I'
		@insert_dialect = arg
		@header_row = false
		break
	when '-D'
		MDB::mdb_set_date_fmt(arg)
		break
	when '-X'
		@escape_char = arg
		break
	when '-N'
		@namespace = arg
		break
  else
		break
  end
end

if ARGV.length < 2
	STDERR.puts "Usage: #{argv[0]} [options] <file> <table>"
	STDERR.puts "where options are:"
	STDERR.puts "  -H             supress header row"
	STDERR.puts "  -Q             don't wrap text-like fields in quotes"
	STDERR.puts "  -d <delimiter> specify a column delimiter"
	STDERR.puts "  -R <delimiter> specify a row delimiter"
	STDERR.puts "  -I <backend>   INSERT statements (instead of CSV)"
	STDERR.puts "  -D <format>    set the date format (see strftime(3) for details)"
	STDERR.puts "  -q <char>      Use <char> to wrap text-like fields. Default is \"."
	STDERR.puts "  -X <char>      Use <char> to escape quoted characters within a field. Default is doubling."
	STDERR.puts "  -N <namespace> Prefix identifiers with namespace"
	exit(1)
end	

@file_name = ARGV[0]
@table_name = ARGV[1]

@mdb = MDB::mdb_open(@file_name, :no_flags)

exit(1) if !@mdb

if @insert_dialect
	if MDB::mdb_set_default_backend(@mdb, @insert_dialect) == 0
		STDERR.puts "Invalid backend type"
		exit(1)
	end
end

@table = MDB::mdb_read_table_by_name(@mdb, @table_name, :table)

if !@table
	STDERR.puts "Error: Table #{@table_name} does not exist in this database."
	MDB::mdb_close(@mdb)
	exit(1)
end

MDB::mdb_read_columns(@table)
MDB::mdb_rewind_table(@table)

@number_of_columns = @table[:num_cols].to_i
@bound_values = Array.new(@number_of_columns)

0.upto(@number_of_columns - 1) do |j|
  value = MDB::BoundValue.new
  value[:value].to_ptr.put_string(0, "")

  length = MDB::BoundLength.new
  length[:len] = 0

  @bound_values[j] = [value, length]

  MDB::mdb_bind_column @table, j+1, @bound_values[j][0].to_ptr, @bound_values[j][1].to_ptr
end

column_pointers = MDB::PtrArray.new @table[:columns]

@columns = column_pointers[:pdata].read_array_of_type(:pointer, :read_pointer, column_pointers[:len]).map do |pointer|
  pointer.null? ? nil : MDB::MdbColumn.new(pointer)
end.compact

if @header_row
  @columns.each_with_index do |column,i|
		print @delimiter if i > 0
		print column[:name]
  end
	puts ""
end

while(MDB::mdb_fetch_row(@table) != 0) do
	if @insert_dialect
	  quoted_name = @mdb[:default_backend][:quote_schema_name].call(@namespace, @table_name)
		print "INSERT INTO #{quoted_name} ("
    @columns.each_with_index do |column,j|
			print ', '	if j > 0
			quoted_name = @mdb[:default_backend][:quote_schema_name].call(nil, column[:name])
			print quoted_name
		end
		print ") VALUES ("
	end

  @columns.each_with_index do |column,j|
		print @delimiter if j > 0
		if @bound_values[j][1][:len] == 0
		  print "NULL" if @insert_dialect
		else
      length = value = nil
			if column[:col_type] == :ole
        length = FFI::MemoryPointer.new(:int)
				value = MDB::mdb_ole_read_full(@mdb, column, length)
		  else
				value = @bound_values[j][0]
				length = @bound_values[j][1]
			end
			print_col(value, @quote_text, column[:col_type], @quote_char, @escape_char)
		end
	end
  print ");" if @insert_dialect
  print @row_delimiter
end

MDB::mdb_free_tabledef(@table)
MDB::mdb_close(@mdb)
