$(document).ready ->
	$(".struct-view").each ->
		foo = new StructView(this)

class StructView extends PluginAdapter

	constructor: (div) ->
		@id = 		"struct_10"
		@div =  div
		@_data =  null
		@actions = []
		super @div.getAttribute("plugin")

	handle_msg: (data) ->
		if data["type"] == "update"
			this.dump_values(data["data"])
			$(@div).contextPopup  title: this.get_context_title, items:  this.get_context_items, view: this
		else if data["type"] == "actions"
			this.set_actions(data["actions"])
		else
			console.log "unknown data", data

	dump_array: (arr, div) ->
		$(div).append("<ol class=\"sv-array\"></ol>")
		list = $(div).children("ol")
		for elem in arr
			list.append("<li class=\"sv-array-elem\"></li>")
			this.dump_values(elem, list.children("li").last().get(0) )
		list.children('li:nth-child(odd)').addClass('sv-odd')

	dump_object: (obj, div) ->
		$(div).append("<ol class=\"sv-obj\"></ol>")
		list = $(div).children("ol")
		for key, elem of obj
			if elem[key]
				desc = "<span class=\"sv-align1\">#{key}</span>: #{elem[key]}"
				delete elem[key]
			else
				desc = "<span class=\"sv-align2\">#{key}</span>:&nbsp;"
			list.append("<li><div class=\"sv-obj-elem\"><div class=\"sv-title\" name=\"#{key}\">#{desc}</div><div class=\"sv-content\"></div></div></li>")
			if !(typeof(elem) == "number" || typeof(elem) == "string")
				list.children("li").last().children("div").last().children(".sv-content").toggle()
				list.children("li").last().children("div").last().children(".sv-title").click ->
					$(this).parent().children(".sv-content").toggle()
			this.dump_values(elem, list.children("li").last().children("div").last().children("div").last().get(0) )
		list.children('li:nth-child(odd)').addClass('sv-odd')

	dump_number: (number, div) ->
		div.innerHTML = "#{number}"

	dump_string: (str, div) ->
		div.innerHTML = str

	do_context_action: (event, action, name) ->
			json = { type: "action", action: action, name: name }
			str = JSON.stringify(json)
			this.send_msg_data( str )
		
	context_function: (self, action, name) ->
		return (event) -> self.do_context_action(event, action, name)

	set_actions: (msg_actions) ->
		@actions = []
		for action, _ in msg_actions
			@actions.push {icon: action.icon, label: action.label, action: null}

	get_context_items: (event) ->
		hovered = this.get_hovered_dom_obj(event)
		name = $( hovered ).closest(".sv-title").get(0).getAttribute("name")
		actions = []
		for action, _ in @actions
			if action
				actions.push {
											label: action.label, 
											icon: action.icon, 
											action: this.context_function(this, action.label, name)}
			else
				actions.push null
		return actions

	get_hovered_dom_obj: (event) ->
			return document.elementFromPoint(event.clientX, event.clientY);

	get_context_title: () ->
			return "title"

	dump_values: (values, div = null) ->
		if div == null
			@_data = values
			div = @div
			@div.innerHTML = ""
		if typeof(values) and values instanceof Array
			this.dump_array(values, div)
		else if typeof(values) == "number"
			this.dump_number(values, div)
		else if typeof(values) == "string"
			this.dump_string(values, div)
		else
			this.dump_object(values, div)
