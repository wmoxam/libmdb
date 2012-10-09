# Ruby port of mdb-sql
# https://github.com/brianb/mdbtools/blob/master/src/util/mdb-sql.c

require 'getoptlong'
require 'rubygems'
require '../lib/mdbsql'
require "readline"

def do_set_cmd(sql, s)
	command_parts = s.split(" \t\n")

  case command_parts[0]
  when nil
    puts "Usage: set [stats|showplan|noexec] [on|off]"
		return
  when "stats"
		case command_parts[1]
    when nil
			puts "Usage: set stats [on|off]"
			return
		when "on"
			MDB::mdb_stats_on(sql[:mdb])
		when "off"
			MDB::mdb_stats_off(sql[:mdb])
			MDB::mdb_dump_stats(sql[:mdb])
		else
			puts "Unknown stats option #{command_parts[1]}"
			puts "Usage: set stats [on|off]"
		end
	when "showplan"
    case command_parts[1]
    when nil
			puts "Usage: set showplan [on|off]"
			return
		when "on"
			showplan = true
		when "off"
			showplan = false
		else
			puts "Unknown showplan option #{command_parts[1]}"
			puts "Usage: set showplan [on|off]"
		end
	when "noexec"
    case command_parts[1]
    when nil
			puts "Usage: set noexec [on|off]"
			return
		when "on"
			@noexec = true
		when "off"
			@noexec = false
		else
			puts "Unknown noexec option #{command_parts[1]}"
			puts "Usage: set noexec [on|off]"
		end
	else
		puts "Unknown set command #{command_parts[0]}"
		puts "Usage: set [stats|showplan|noexec] [on|off]"
	end
end

def read_file(filename, current_line)
  file = File.open filename, 'r'
	if !file
		STDERR.puts "Unable to open file #{filename}"
		return 0
	end

  read_lines = 0
  Readline.input = file

  while line = Readline.readline
		read_lines += 1
    @sql_buffer << line.chomp
		puts "#{current_line + lines} => #{@sql_buffer.last}"
	end
	lines
end

def run_query(out_file, sql, sql_text, delimiter)
	MDB::SQL::mdb_sql_run_query(sql, sql_text)
	if !MDB::SQL::mdb_sql_has_error?(sql)
		if @showplan
			table = sql[:cur_table]
			if table[:sarg_tree] != 0
        MDB::SQL::mdb_sql_dump_node(table[:sarg_tree], 0)
      end
			if sql[:cur_table][:strategy] == :table_scan
				puts "Table scanning #{table[:name]}"
			else
				puts "Index scanning #{table[:name]} using #{table[:scan_idx][:name]}"
      end
		end
		if @noexec
			MDB::SQL::mdb_sql_reset(sql)
			return
		end
		
    MDB::SQL::mdb_sql_bind_all(sql)
		
    if @pretty_print
			dump_results_pp(out_file, sql)
		else
			dump_results(out_file, sql, delimiter)
    end
  else
   puts "ERROR!! #{sql[:error_msg]}"
	end
end

def print_value(out_file, v, sz, first)
  out_file.print '|' if first
  out_file.print "#{v}#{' ' * (sz - v.length)}|"
end

def print_break(out_file, sz, first)
  out_file.print '+' if first
  out_file.print "#{'-' * sz}+"
end

def print_rows_retrieved(out_file, row_count)
	if row_count.nil? || row_count == 0
		out_file.puts "No Rows retrieved"
	elsif row_count == 1
		out_file.puts "1 Row retrieved"
	else
		out_file.puts "%d Rows retrieved" % row_count
  end
	out_file.flush
end

def dump_results(out_file, sql, delimiter)
  column_pointers = MDB::PtrArray.new sql[:columns]

  columns = column_pointers[:pdata].read_array_of_type(:pointer, :read_pointer, column_pointers[:len]).map do |pointer|
    pointer.null? ? nil : MDB::SQL::MdbSQLColumn.new(pointer)
  end.compact


	if @headers
		columns.each do |sqlcol|
      d = if sqlcol == columns.last
        ""
      else
        delimiter ? delimiter : "\t"
      end
			out_file.print "#{sqlcol[:name]}#{d}"
		end
		out_file.puts ""
		out_file.flush
	end

  row_count = 0

	while(MDB::mdb_fetch_row(sql[:cur_table]) != 0) do
		row_count += 1
  	columns.each_with_index do |sqlcol,j|
      d = if sqlcol == columns.last
        ""
      else
        delimiter ? delimiter : "\t"
      end
			out_file.print "#{sql[:bound_values][j]}#{d}"
		end
    out_file.puts ""
		out_file.flush
	end
	if @footers
		print_rows_retrieved(out_file, row_count)
	end

	MDB::SQL::mdb_sql_reset(sql)
end

def dump_breaks(out_file, display_sizes)
  display_sizes.each_with_index do |size,j|
  	print_break(out_file, size, j == 0)
	end
  out_file.puts ""
	out_file.flush
end

def dump_results_pp(out_file, sql)
  column_pointers = MDB::PtrArray.new sql[:columns]

  columns = column_pointers[:pdata].read_array_of_type(:pointer, :read_pointer, column_pointers[:len]).map do |pointer|
    pointer.null? ? nil : MDB::SQL::MdbSQLColumn.new(pointer)
  end.compact


	if @headers
		columns.each do |sqlcol|
      if sqlcol[:name].length > sqlcol[:disp_size]
				sqlcol[:disp_size] = sqlcol[:name].length
      end
			print_break(out_file, sqlcol[:disp_size], sqlcol == columns.first)
		end
		out_file.puts ""
		out_file.flush

    display_sizes = columns.collect {|c| c[:disp_size] }
    dump_breaks out_file, display_sizes

    columns.each do |sqlcol|
			print_value(out_file, sqlcol[:name], sqlcol[:disp_size], sqlcol == columns.first)
		end
		out_file.puts ""
		out_file.flush

	end

  dump_breaks out_file, display_sizes

  row_count = 0

	while(MDB::mdb_fetch_row(sql[:cur_table]) != 0) do
		row_count += 1
    columns.each_with_index do |sqlcol,j|
			print_value(out_file, sql[:bound_values][j].read_string, sqlcol[:disp_size], sqlcol == columns.first)
		end
    out_file.puts ""
	  out_file.flush
	end

  dump_breaks out_file, display_sizes

  print_rows_retrieved(out_file, row_count) if @footers
	
  MDB::SQL::mdb_sql_reset(sql)
end

def usage
  puts "Unknown option.\nUsage: %s [-HFp] [-d <delimiter>] [-i <file>] [-o <file>] <database>" % __FILE__
end

@in_file = @out_file = @delimiter = nil
@headers = true
@footers = true
@pretty_print = true
@showplan = false
@noexec = false
@sql_buffer = []

opts = GetoptLong.new(
  [ '-p', GetoptLong::NO_ARGUMENT ],
  [ '-d', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-H', GetoptLong::NO_ARGUMENT ],
  [ '-F', GetoptLong::NO_ARGUMENT ],
  [ '-i', GetoptLong::REQUIRED_ARGUMENT ],
  [ '-o', GetoptLong::REQUIRED_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
  when '-d'
    @delimiter = arg
  when '-p'
    @pretty_print = true
  when '-H'
    @headers = true
  when '-F'
    @footers = true
  when '-i'
    if arg == 'stdin'
      @in_file = STDIN
    else
      @in_file = File.open(arg, 'r')
    end
  when '-o'
    @out_file = File.open(arg, 'w')
  else
    usage
    exit(1)
  end
end

if ARGV.length < 1
  usage
  exit(1)
end


sql = MDB::SQL::mdb_sql_init()
MDB::SQL::mdb_sql_open(sql, ARGV[0])

@line_number = 0
s = ""
mybuf = ""

@out_file ||= STDOUT
@in_file ||= STDIN

while true
	@line_number += 1
	if !@in_file.tty?
    @in_file.each_line do |line_text|
		  run_query(@out_file, sql, line_text, @delimiter)
		end
    @in_file = STDIN
  else
		s = Readline.readline("%d => " % @line_number, true)
  end

	break if s =~ /exit|quit|bye/i

  case s
  when /^\s*set/i
		do_set_cmd(sql, s)
    line_number = 0
	when /^\s*go/i
		line_number = 0;
		run_query(@out_file, sql, @sql_buffer.join('\n'), @delimiter)
		@sql_buffer = []
  when /^\*reset/i
		line_number = 0
		@sql_buffer = []
	when /^:r/
		line_number += read_file(s, line_number)
  else
    @sql_buffer << s
  end
end

MDB::SQL::mdb_sql_exit(sql)

@out_file.close unless @out_file.tty?
@in_file.close unless @in_file.tty?

