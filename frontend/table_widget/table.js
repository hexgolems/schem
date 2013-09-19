var AddressedTable,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

$(document).ready(function() {
  return $(".code-table-view").each(function() {
    var foo;
    return foo = new AddressedTable(this);
  });
});

AddressedTable = (function(_super) {

  __extends(AddressedTable, _super);

  AddressedTable.prototype.id = "table_10";

  AddressedTable.prototype.div = null;

  AddressedTable.prototype.table = null;

  AddressedTable.prototype._num_rows = 100;

  AddressedTable.prototype._data = [];

  AddressedTable.prototype._offset = 0;

  AddressedTable.prototype._already_waiting_for_update = false;

  function AddressedTable(div) {
    this.div = div;
    AddressedTable.__super__.constructor.call(this, "cpuview");
    this.cols = {
      address: 0,
      inst: 1
    };
    this.make_table(100, 2);
  }

  AddressedTable.prototype.handle_msg = function(data) {
    var offset_data;
    console.log("table input", data);
    if (data["type"] === "update") {
      this.dump_values(data["data"]);
      offset_data = data["offset_data"];
      if (offset_data["type"] === "fixed") {
        this.set_offset(offset_data["offset"]);
      } else if (offset_data["type"] === "align") {
        this.replace_aligned(offset_data["old_line"], offset_data["new_line"], data["data"]);
      } else {
        console.log("unknown offset data in", data);
        alert(120);
      }
      return this._already_waiting_for_update = false;
    } else {
      return console.log("unknown data", data);
    }
  };

  AddressedTable.prototype.get_data = function(addr, lines_before, offset_data) {
    var str;
    if (this._already_waiting_for_update) return;
    this._already_waiting_for_update = true;
    str = JSON.stringify({
      type: "req",
      address: addr,
      lines_before: lines_before,
      length: this._num_rows,
      offset_data: offset_data
    });
    return this.send_msg_data(str);
  };

  AddressedTable.prototype.goto_addr = function(addr) {
    return this.get_data(addr, 4, {
      type: "fixed",
      offset: 0
    });
  };

  AddressedTable.prototype.replace_aligned = function(old_line, new_line, data) {
    var new_line_top, old_line_top, old_offset, old_top;
    old_top = this.table.offsetTop;
    old_line_top = this.table.rows[old_line].offsetTop;
    old_offset = this.offset;
    this.dump_values(data);
    new_line_top = this.table.rows[new_line].offsetTop;
    return this.set_offset(this._offset + (old_line_top - new_line_top));
  };

  AddressedTable.prototype.reload_top = function() {
    var addr;
    addr = this._data[0].address;
    return this.get_data(addr, this._data.length - 30, {
      type: "align",
      old_line: 0,
      new_line: this._data.length - 30
    });
  };

  AddressedTable.prototype.reload_bottom = function() {
    var addr;
    addr = this._data[this._data.length - 1].address;
    return this.get_data(addr, 29, {
      type: "align",
      old_line: this._data.length - 1,
      new_line: 29
    });
  };

  AddressedTable.prototype.scroll = function(delta) {
    var dist_bottom, dist_top, _ref;
    if (this._offset + delta > 0) if (this._first_row === 0) return;
    this.set_offset(this._offset + delta);
    _ref = this.content_dists(), dist_top = _ref[0], dist_bottom = _ref[1];
    if (dist_top <= 0) this.reload_top();
    if (dist_bottom <= 0) return this.reload_bottom();
  };

  AddressedTable.prototype.div_offset_top = function() {
    var div_border_width, div_top;
    div_border_width = parseInt($(this.div).css("border-top-width"));
    return div_top = this.div.offsetTop + div_border_width;
  };

  AddressedTable.prototype.content_dists = function() {
    var div_bottom, div_top, table_bottom, table_bottom_dist, table_top_dist;
    div_top = this.div_offset_top();
    div_bottom = div_top + this.div.offsetHeight;
    table_bottom = this.table.offsetTop + this.table.offsetHeight;
    table_bottom_dist = table_bottom - div_bottom;
    table_top_dist = div_top - this.table.offsetTop;
    return [table_top_dist, table_bottom_dist];
  };

  AddressedTable.prototype.set_offset = function(offset) {
    this._offset = offset;
    return $(this.table).css("top", offset);
  };

  AddressedTable.prototype.make_table = function(num_rows, num_cols) {
    var col, cols, rows,
      _this = this;
    col = "<td class=\"hwtd\">foo</td>";
    cols = "<td class=\"hwtdf\">foo</td>" + Array(num_cols).join(col);
    rows = Array(num_rows / 2 + 1).join("<tr class=\"hwtre\">" + cols + "</tr><tr class=\"hwtro\">" + cols + "</tr>");
    this.div.innerHTML = "<table class=\"hwtable\" id=\"" + this.table_id + "\"> " + rows + " </table>";
    this.table = this.div.children[0];
    $(this.table).bind("mousewheel", function(e) {
      return _this.scroll(e.originalEvent.wheelDelta / 6);
    });
    return $(this.div).bind("keydown", function(e) {
      console.log("key", e.keyCode, e.which, 'G'.charCodeAt(0));
      if ((e.keyCode || e.which) === 'G'.charCodeAt(0)) {
        return _this.goto_addr(prompt("Address", 0x400020));
      }
    });
  };

  AddressedTable.prototype.dump_values = function(values) {
    var col_index, col_name, innercell, innerrow, row, row_key, _results;
    this._data = values;
    console.log("addr: " + values[0].address + ".." + values[values.length - 1].address);
    _results = [];
    for (row_key in values) {
      row = values[row_key];
      _results.push((function() {
        var _ref, _results2;
        _ref = this.cols;
        _results2 = [];
        for (col_name in _ref) {
          col_index = _ref[col_name];
          innerrow = this.table.rows[row_key];
          innercell = innerrow.cells[col_index];
          _results2.push(innercell.innerHTML = row[col_name]);
        }
        return _results2;
      }).call(this));
    }
    return _results;
  };

  return AddressedTable;

})(PluginAdapter);
