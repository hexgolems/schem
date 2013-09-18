$(document).ready ->
	$("mem-table-view").each ->
		foo = new MemTable(this)

class MemTable extends PluginAdapter
	id:		"mem_10"
	div: null
	table: null
	_num_rows: 100
	_data: []
	_offset: 0
	_already_waiting_for_update: false

	constructor: (@div) ->
		super "memview"
		@cols = {address: 0, inst: 1}
		this.make_table(100,4)

	handle_msg: (data) ->
		console.log "mem input", data
		if data["type"] == "update"
			this.dump_values(data["data"])
			offset_data = data["offset_data"]

			if offset_data["type"] == "fixed"
				this.set_offset(offset_data["offset"])
			else if offset_data["type"] == "align"
				this.replace_aligned( offset_data["old_line"], offset_data["new_line"], data["data"] )
			else
				console.log("unknown offset data in", data);alert(120)
			@_already_waiting_for_update = false
		else
			console.log "unknown data", data

	get_data: (addr, lines_before, offset_data) ->
		return if @_already_waiting_for_update
		@_already_waiting_for_update = true
		str = JSON.stringify({
			type: "req", 
			address: addr, 
			lines_before: lines_before, 
			length: @_num_rows,
			offset_data: offset_data
			})
		this.send_msg_data( str )
	
	goto_addr: (addr) ->
		this.get_data(addr, 4, {type: "fixed", offset: 0})

	replace_aligned: (old_line, new_line, data) ->
			old_top = @table.offsetTop
			old_line_top = @table.rows[old_line].offsetTop
			old_offset = @offset
			this.dump_values(data)
			new_line_top = @table.rows[new_line].offsetTop
			this.set_offset(@_offset + (old_line_top - new_line_top))

	reload_top: () ->
		addr = @_data[0].address
		this.get_data(addr,@_data.length-30, {type: "align", old_line: 0, new_line: @_data.length-30})

	reload_bottom: () ->
		addr = @_data[@_data.length-1].address
		this.get_data(addr, 29, {type: "align", old_line: @_data.length-1, new_line: 29})

	scroll: (delta) ->
		if @_offset+delta > 0 
			if @_first_row == 0
				return 
		this.set_offset(@_offset+delta)
		[dist_top, dist_bottom] = this.content_dists()
		if dist_top <= 0
			this.reload_top()
		if dist_bottom <=0
			this.reload_bottom()

	div_offset_top: () ->
		div_border_width =  parseInt($(@div).css("border-top-width"))
		div_top = @div.offsetTop+div_border_width

	content_dists: () ->
		div_top = this.div_offset_top()
		div_bottom = div_top + @div.offsetHeight
		table_bottom = @table.offsetTop + @table.offsetHeight
		table_bottom_dist = table_bottom - div_bottom 
		table_top_dist = div_top - @table.offsetTop 
		return [table_top_dist, table_bottom_dist]

	set_offset: (offset) ->
		@_offset = offset
		$(@table).css("top",offset)

	make_table: (num_rows, num_cols) ->
		col = "<td class=\"hwtd\">foo</td>"
		cols = "<td class=\"hwtdf\">foo</td>" + Array(num_cols).join(col)
		#string*num is done this fucking strange way...
		rows = Array(num_rows/2+1).join "<tr class=\"hwtre\">#{cols}</tr><tr class=\"hwtro\">#{cols}</tr>"  
		@div.innerHTML = "<table class=\"hwtable\" id=\"#{@table_id}\"> #{rows} </table>"
		@table = @div.children[0]
		$(@table).bind "mousewheel", (e) =>
			this.scroll(e.originalEvent.wheelDelta/6)
		$(@div).bind "keydown", (e) =>
			console.log "key", e.keyCode, e.which, 'G'.charCodeAt(0)
			if (e.keyCode || e.which) == 'G'.charCodeAt(0)
				address = prompt("Address", 0x400020)
				if(address)
					this.goto_addr(address)

	dump_values: (values) ->
		@_data = values
		console.log "addr: #{values[0].address}..#{values[values.length-1].address}"
		for row_key,row of values
			for col_name,col_index of @cols
				innerrow = @table.rows[row_key]
				innercell = innerrow.cells[col_index]
				innercell.innerHTML = row[col_name]
