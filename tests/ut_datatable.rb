#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR DataTable datatype

require 'test/unit'

require 'plan-r/datatype/data_table'

# ----------------------------------------------------------------------

class TC_DataTableTest < Test::Unit::TestCase

  def test_1_basic_table_use
    # define a table of 5 columns
    dt = PlanR::DataTable.new(5)

    # should have 0 rows
    assert_equal(0, dt.rows.count)
    # should have 5 (empty) columns
    assert_equal(5, dt.cols.count)
    # should have size of 0
    assert_equal(0, dt.count)
    # should have order of 5 
    assert_equal(5, dt.order)
    # headers should be empty
    assert_equal(nil, dt.header)
    # incorrect header size should raise exception
    assert_raises(RuntimeError) {
      dt.header = %w{a b c d}
    }
    assert_raises(RuntimeError) {
      dt.header = %w{a b c d e f}
    }
    # incorrect header elem type should raise exception
    assert_raises(RuntimeError) {
      dt.header = [1,2,3,4,5]
    }
    # headers can be set
    dt.header = %w{a b c d e}
    assert_equal(['a','b','c','d','e'], dt.header)
    assert_equal('["a", "b", "c", "d", "e"][]', dt.inspect)
    assert_equal('a', dt.header[0])
    assert_equal('b', dt.header[1])
    assert_equal('c', dt.header[2])
    assert_equal('d', dt.header[3])
    assert_equal('e', dt.header[4])

    # Refer to a column by header

    # incorrect row size raises exception
    assert_raises(RuntimeError) {
      dt << [1,2,3,4]
    }
    assert_raises(RuntimeError) {
      dt << [1,2,3,4,5,6]
    }
    # adding a row works
    dt << [1,2,3,4,5]
    assert_equal(1, dt.count)
    assert_equal(1, dt.rows.count)
    assert_equal(5, dt.cols.count)
    assert_equal('["a", "b", "c", "d", "e"][[1, 2, 3, 4, 5]]', dt.inspect)
    assert_equal([1,2,3,4,5], dt.rows.first)
    assert_equal([1,2,3,4,5], dt[0])
    assert_equal(1, dt[0][0])
    assert_equal(2, dt[0][1])
    assert_equal(3, dt[0][2])
    assert_equal(4, dt[0][3])
    assert_equal(5, dt[0][4])

    dt.append [5,4,3,2,1]
    assert_equal(2, dt.count)
    assert_equal(2, dt.rows.count)
    assert_equal(5, dt.cols.count)
    assert_equal(5, dt[1][0])
    assert_equal(4, dt[1][1])
    assert_equal(3, dt[1][2])
    assert_equal(2, dt[1][3])
    assert_equal(1, dt[1][4])

    dt.insert(1, [0,0,0,0,0])
    assert_equal(0, dt[1][0])
    assert_equal(0, dt[1][1])
    assert_equal(0, dt[1][2])
    assert_equal(0, dt[1][3])
    assert_equal(0, dt[1][4])
    assert_equal(5, dt[2][0])
    assert_equal(4, dt[2][1])
    assert_equal(3, dt[2][2])
    assert_equal(2, dt[2][3])
    assert_equal(1, dt[2][4])

    assert_raises(RuntimeError) {
      dt[1] = [1,2,3,4]
    }
    dt[1] = [2,2,2,2,2]
    assert_equal(2, dt[1][0])
    assert_equal(2, dt[1][1])
    assert_equal(2, dt[1][2])
    assert_equal(2, dt[1][3])
    assert_equal(2, dt[1][4])

    dt[1][0] = 3
    assert_equal(3, dt[1][0])
    dt[1][4] = 3
    assert_equal(3, dt[1][0])

    # delete a row
    dt.delete(1)
    assert_equal(2, dt.count)
    assert_equal(5, dt[1][0])
    assert_equal(4, dt[1][1])
    assert_equal(3, dt[1][2])
    assert_equal(2, dt[1][3])
    assert_equal(1, dt[1][4])

    # Add a column
    dt.append_col()
    assert_equal(6, dt.order)
    dt.append_col('x')
    assert_equal(7, dt.order)
    assert_raise(RuntimeError) {
      dt.append_col('x', 0)
    }
    dt.append_col('y', 0)
    assert_equal(8, dt.order)
    assert_equal(0, dt[0][dt.order-1])
    dt.append_col('', 'a')
    assert_equal(9, dt.order)
    assert_equal('a', dt[0][dt.order-1])
    dt.insert_col(5, 's', 1)
    assert_equal(10, dt.order)
    assert_equal(1, dt[0][5])
    assert_equal('e', dt.col_name(4))
    assert_equal('s', dt.col_name(5))
    assert_equal('', dt.col_name(6))
    assert_equal('x', dt.col_name(7))

    # Remove a column
    dt.delete_col(5)
    assert_equal(9, dt.order)
    assert_equal('', dt.col_name(5))
    assert_equal('x', dt.col_name(6))
  end

  def test_2_json_conv
    dt = PlanR::DataTable.new(5)
    dt.header = %w{c1 c2 c3 c4 c5}
    dt << [1,0,1,0,1]
    dt << [0,1,0,1,0]
    dt << [10,20,30,40,50]
    assert_equal('{"json_class":"PlanR::DataTable","data":{"header":["c1","c2","c3","c4","c5"],"order":5,"rows":[[1,0,1,0,1],[0,1,0,1,0],[10,20,30,40,50]]}}',
                 dt.to_json)
    dtj = PlanR::DataTable.from_json(dt.to_json)
    assert(dtj)
    assert_equal(dt.order, dtj.order)
    assert_equal(dt.header, dtj.header)
    assert_equal(dt.rows, dtj.rows)
    assert_equal(dt.columns, dtj.columns)
  end

  def test_3_r_conv
  end
end
