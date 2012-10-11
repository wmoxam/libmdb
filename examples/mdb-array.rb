# Ruby port of mdb-array
# https://github.com/brianb/mdbtools/blob/master/src/util/mdb-array.c

require 'rubygems'
require 'libmdb'

if ARGV.length < 2
  STDERR.puts "Usage: #{__FILE__} <file> <table>"
  exit
end

file = ARGV[0]
table_name = ARGV[1]

delimiter = ", "

mdb = MDB::mdb_open(file, :no_flags)
table = MDB::mdb_read_table_by_name(mdb, table_name, :table)

if table
  MDB::mdb_read_columns table
  MDB::mdb_rewind_table table

  number_of_columns = table[:num_cols].to_i

  bound_values = Array.new(number_of_columns)
  0.upto(number_of_columns - 1) do |j|
    value = MDB::BoundValue.new
    value[:value].to_ptr.put_string(0, "")

    length = MDB::BoundLength.new
    length[:len] = 0

    bound_values[j] = [value, length]

	  MDB::mdb_bind_column table, j+1, bound_values[j][0].to_ptr, bound_values[j][1].to_ptr
	end

	puts "/******************************************************************/"
	puts "/* THIS IS AN AUTOMATICALLY GENERATED FILE.  DO NOT EDIT IT!!!!!! */"
	puts "/******************************************************************/"
	puts ""
	puts "#include <stdio.h>"
	puts "#include \"types.h\""
	puts "#include \"dump.h\""
	puts ""
	puts "const #{table_name} #{table_name}_array [] = {"

	count = 0
	started = 0
	while(MDB::mdb_fetch_row(table) != 0) do
		puts "," if started != 0
	  started = 1;
	  print "{\t\t\t\t/* %6d */\n\t" % count

    column_pointers = MDB::PtrArray.new table[:columns]

    columns = column_pointers[:pdata].read_array_of_type(:pointer, :read_pointer, column_pointers[:len]).map do |pointer|
      pointer.null? ? nil : MDB::MdbColumn.new(pointer)
    end.compact

    0.upto(number_of_columns - 1) do |j|
      next if bound_values[j][0].nil?
		  print "\t"

      if columns[j][:col_type] == :text || columns[j][:col_type] == :memo
		    print "\"#{bound_values[j][0][:value]}\""
		  else
		    print bound_values[j][0][:value]
		  end

      if j != number_of_columns - 1
		    puts delimiter
		  else
		    puts ""
	    end
    end
	  print "}"
	  count += 1
  end
  puts "\n};\n"

  MDB::mdb_free_tabledef table
end

MDB::mdb_close mdb

puts "const int #{table_name}_array_length = #{count};"

