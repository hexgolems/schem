$(document).ready ->
	$(".lane-view").each ->
		foo = new LaneTable(this)

class LaneTable extends PluginAdapter

	constructor: (div) ->

		@div =  div
		@table =  null
		@_num_rows =  50
		@_low_address =  0
		@_high_addr =  0
		@_offset =  0
		@_already_waiting_for_update =  false
		@lane_actions =  []
		super @div.getAttribute("plugin")
		this.make_table(30)

	handle_msg: (msg) ->
		if msg.type == "update"
			this.dump_values(msg.lanes)
			@line_length = msg.line_length
			@_low_address = msg.low_address
			@_high_address = msg.high_address
			offset_data = msg.offset_data

			if offset_data.type == "fixed"
				this.set_offset(offset_data["offset"])
			else if offset_data.type == "align"
				this.replace_aligned( offset_data.old_line, offset_data.new_line, msg.lanes )
			else if offset_data.type == "delta"
				#no moving stuff around when a deltat update is encountered
				this.set_offset (@_offset) # but we will need to fix the table anyway
			else
				console.log("unknown offset data in", data);alert(120)
			@_already_waiting_for_update = false
		else if msg.type = "actions"
			this.set_lane_actions msg.actions
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
	
	goto_addr: (addr, before=4) ->
		this.get_data(addr, before, {type: "fixed", offset: 0})

	replace_aligned: (old_line, new_line, data) ->
			old_top = @table.offsetTop
			old_line_top = @table.rows[old_line].offsetTop
			old_offset = @offset
			this.dump_values(data)
			new_line_top = @table.rows[new_line].offsetTop
			this.set_offset(@_offset + (old_line_top - new_line_top))

	reload_top: () ->
		this.get_data(@_low_address,@_num_rows-30, {type: "align", old_line: 0, new_line: @_num_rows-30})

	reload_bottom: () ->
		this.get_data(@_high_address, 29, {type: "align", old_line: @_num_rows-1, new_line: 29})

	scroll: (delta) ->
		if @_offset+delta > 0 
			if @_first_row == 0
				return 
		this.set_offset(@_offset+delta)
		[dist_top, dist_bottom] = this.content_dists()
		if dist_top <= 30
			this.reload_top()
		if dist_bottom <=30
			this.reload_bottom()

	div_offset_top: () ->
		div_border_width =  parseInt($(@div).css("border-top-width"))
		div_top = @div.offsetTop+div_border_width

	content_dists: () ->
		div_pos = $(@div).offset();
		table_pos = $(@table).offset();
		dist_top = div_pos.top - table_pos.top

		div_bottom = div_pos.top + @div.offsetHeight
		table_bottom = table_pos.top + @table.offsetHeight
		dist_bottom = table_bottom - div_bottom 
		return [dist_top, dist_bottom]

	set_offset: (offset) ->
		@_offset = offset
		$(@table).css("top",offset)


	get_item_start: (item) ->
		return item.getAttribute("a")

	get_item_end: (item) ->
		addr_end_bi = str2bigInt(item.getAttribute("a"), 16, 64, 2)
		addr_end_bi = addInt(addr_end_bi, parseInt(item.getAttribute("colspan") || "1") - 1)
		return bigInt2str(addr_end_bi, 16)

	get_selection: () ->
		return null if window.getSelection().type == "None"
		selectedRange = window.getSelection().getRangeAt(0)
		end = selectedRange.endContainer
		start = selectedRange.startContainer
		addr_start = this.get_item_start($(start).closest("[a]").get(0))
		addr_end = this.get_item_end($(end).closest("[a]").get(0))
		return { start: addr_start, end: addr_end }

	get_lane_of_item: (item) ->
		return null unless item
		row = $(item).closest("tr").get(0)
		lane = 0
		for c,i in row.cells
			lane += 1 if $(c)[0].classList.contains("lv-lane-sep")
			return lane if c == item
		return null

	do_context_action: (event,action,lane,item,selection) ->
			item_range = {start: this.get_item_start(item), end: this.get_item_end(item)}
			json = {type: "action", action: action, lane: lane, item_range: item_range, selection_range: selection }
			str = JSON.stringify(json)
			this.send_msg_data( str )
		
	context_function: (self,action,lane,item,selection) ->
		return (event) -> self.do_context_action(event,action,lane,item,selection)

	set_lane_actions: (msg_actions) ->
		console.log msg_actions
		for actions,lane in msg_actions
			@lane_actions[lane] = []
			for action,_ in actions
				@lane_actions[lane].push {icon: action.icon, label: action.label, action: null}

	get_context_items: (event) ->
		selection = this.get_selection()
		hovered = this.get_hovered_dom_obj(event)
		item = $( hovered ).closest("[a]").get(0)
		lane = this.get_lane_of_item(item)
		return null if lane == null
		alert("no actions for lane #{lane}") unless @lane_actions[lane]
		actions = []
		for action,_ in @lane_actions[lane]
			if action
				actions.push {
											label: action.label, 
											icon: action.icon, 
											action: this.context_function(this,action.label,lane,item,selection)}
			else
				actions.push null
		return actions

	get_context_title: () ->
			return "title"

	get_hovered_dom_obj: (event) ->
			return document.elementFromPoint(event.clientX, event.clientY);

	make_table: () ->
		@div.innerHTML = "<div class='lv-content'><table class=\"lv-content-table\"><tbody> No memory loaded </tbody></table></div>"
		$(@div).parent().append("<div class='lv-annotation lv-mem-table'> No info </div>")
		@table_div = @div.children[0]
		@annotation_div = $(@div).parent().children().last().get(0)
		$(@div).bind "mousewheel", (e) =>
			this.scroll(e.originalEvent.wheelDelta/4)
		$(@div).bind "keydown", (e) =>
			console.log "key", e.keyCode, e.which, 'G'.charCodeAt(0)
			if (e.keyCode || e.which) == 'G'.charCodeAt(0)
				this.goto_addr( prompt("Address",0x400020), 0 )
		$(@div).contextPopup  title: this.get_context_title, items:  this.get_context_items, view: this
		$(@div).mousemove (event) =>
			hovered = $(this.get_hovered_dom_obj(event)).closest("[a]").get(0)
			if @last_hovered != hovered && hovered && hovered.getAttribute("a")
				@last_hovered = hovered
				address = hovered.getAttribute("a")
				meta = hovered.getAttribute("h")
				while address.length < 8
					address = "0"+address
				meta_cols =["<td><span>#{address}<span></td>"]
				if meta
					meta_data = JSON.parse(unescape(meta))
					for _,tag of meta_data
						if tag[1]
							meta_cols.push "<td><span>#{tag[0]}</span><span>:</span><span>#{tag[1]}</span></td>"
						else
							meta_cols.push "<td><span>#{tag[0]}</span></td>"

				$(@annotation_div).html("<table class='lv-meta-info'><tr>#{meta_cols.join("<td class='sep'/>")}</table>")

	dump_values: (values) ->
		$(@table_div).html( values )
		@table = @table_div.children[0]
