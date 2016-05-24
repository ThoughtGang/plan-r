#!/usr/bin/env ruby
# :title: PlanR::DataTable
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'json'

module PlanR

=begin rdoc
A table of arbitrary data.
This is implemented as a two-dimensional array.
=end
  class DataTable < Array
    include Enumerable

=begin rdoc
An Array of Strings representing column names
=end
    attr_reader :header

=begin rdoc
# of columns in Table.
=end
    attr_reader :order

    def initialize(num_cols, num_rows=0, obj='')
      @order = num_cols
      @header = []
      super num_rows, Array.new(num_cols, obj)
    end

=begin rdoc
Set column headers. Argument is an Array of Strings.
=end
    def header=(hdr)
      order_check(hdr)
      hdr.each {|s| raise "Header must contain strings" if ! s.kind_of? String }
      @header = hdr
    end

=begin rdoc
Return two-dimensional array of rows. Each row is an array of columns.
=end
    def rows
      Array.new self
    end

=begin rdoc
Iterates over data in row, col order.
Yields item, row-index, col-index.
=end
    def each_item
      each_with_index do |r, row|
        row.each_with_index do |item, col|
          yield item, row, col
        end
      end
    end

=begin rdoc
Append a row to the table.
=end
    def <<(arr)
      order_check(arr)
      super
    end

    alias :append :<<
    alias :append_row :<<

=begin rdoc
Insert a row into the table
=end
    def insert(idx, row)
      order_check(row)
      super
    end
    alias :insert_row :insert

=begin rdoc
Set table row data.
Example:
  t = TableData.new(3)
  t[0] = [1, 2, 3]
=end
    def []=(*args)
      # Note: args.first can be [start,length], Range, Fixnum (index)
      raise '[]= can only set rows' if ! args.last.kind_of? Array
      raise '[]= does not support range' if (args.first.kind_of? Range) ||
                                            (args.first.kind_of? Array)
      order_check(args.last)
      super
    end

=begin rdoc
Delete a row from the table.
=end
    alias :delete :delete_at
    alias :delete_row :delete_at

=begin rdoc
Return two-dimensional array of columns. Each column is an array of rows.
=end
    def cols
      count == 0 ? Array.new(@order) :
                  first.inject([]) { |arr, item| 
                                     arr << map { |row| row[arr.count] }; arr }
    end
    alias :columns :cols

    def col_index(name)
      @header.rindex name
    end
    alias :column_index :col_index

    def col_name(idx)
      @header[idx]
    end
    alias :column_name :col_name

=begin rdoc
Returns enumerator over each column.
=end
    def each_col
      cols.each
    end
    alias :each_column :each_col

=begin rdoc
Append a column to the table
=end
    def append_col(name='', obj=nil)
      header_name_check(name)
      @header << name
      @order += 1
      each { |row| row << obj }
    end
    alias :append_column :append_col

=begin rdoc
Insert a column into the table
=end
    def insert_col(idx, name='', obj=nil)
      header_name_check(name)
      @header.insert(idx, name)
      @order += 1
      each { |row| row.insert(idx, obj) }
    end
    alias :insert_column :insert_col

=begin rdoc
Delete column at specified index.
=end
    def delete_col(idx)
      @header.delete_at(idx)
      @order -= 1
      each { |row| row.delete_at(idx) }
    end
    alias :delete_column :delete_col

=begin rdoc
union
=end
    def |(arr)
      raise 'Not Implemented'
    end

=begin rdoc
intersection
=end
    def &(arr)
      raise 'Not Implemented'
    end

=begin rdoc
cartesian product
=end
    def *(obj)
      raise 'Not Implemented'
    end

=begin rdoc
sum
=end
    def +(arr)
      raise 'Not Implemented'
    end

=begin rdoc
difference
=end
    def -(arr)
      raise 'Not Implemented'
    end

    def self.from_json(str)
      begin
        h = JSON.parse str
        json_create(h)
      rescue Exception => e
        $stderr.puts "Unable to parse JSON str '#{str}':\n#{e.message}"
        nil
      end
    end

    def self.json_create(o)
      self.from_h( (o.keys.include? 'json_class') ? o['data'] : o )
    end

    def self.from_h(h)
      num_cols = h['order']
      tbl = DataTable.new(num_cols)

      hdr = h['header']
      tbl.header = hdr if hdr && (! hdr.empty?)

      rows = h['rows']
      rows.each { |row| tbl << row }

      tbl
    end


    def to_h
      { 'order' => @order, 'rows' => rows, 'header' => header }
    end

    def to_json(*a)
      h = { 
        'json_class' => self.class.name,
        'data' => { 'order' => @order, 'rows' => rows, 'header' => header }
      }
      h.to_json(*a)
    end

    def self.to_a
      rows
    end

    # if block is provided, it will be invoked to convert datatype
    def self.from_csv(str, delim=',', header=true, &block)
      rows = str.lines.map { |row| row.split delim }
      rows = rows.map { |row| row.map(&block) } if block_given?
      hdr = rows.shift if header
      num_cols = rows.map { |row| row.length }.max
      tbl = DataTable.new(num_cols)
      tbl.header = hdr if hdr && (! hdr.empty?)
      rows.each { |row| tbl << row }
      tbl
    end

    def inspect
      @header.inspect + super
    end

    private

    def order_check(arr)
      raise "Incorrect column count #{arr.count}" if arr.count != @order
    end

    def header_name_check(str)
      raise "Duplicate column '#{str}'" if str && (! str.empty?) && 
                                           @header.include?(str)
    end
  end

end
