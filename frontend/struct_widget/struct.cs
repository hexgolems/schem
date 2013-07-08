$(document).ready ->
	$(".register-struct-view").each ->
		foo = new StructView(this)
		foo.req_data()

class StructView extends PluginAdapter
	id:		"struct_10"
	div: null
	_data: null

	constructor: (@div) ->
		super "registerview"

	handle_msg: (data) ->
		if data["type"] == "update"
			this.dump_values(data["data"])
		else
			console.log "unknown data", data

	req_data: () ->
		this.send_msg_data( JSON.stringify({type: "req"}) )
	
	dump_array: (arr, div) ->
		$(div).append("<ol class=\"hwstruct-array\"></ol>")
		list = $(div).children("ol")
		for elem in arr
			list.append("<li class=\"hwstruct-array-elem\"></li>")
			this.dump_values(elem, list.children("li").last().get(0) )
		list.children('li:nth-child(odd)').addClass('hwodd');

	dump_object: (obj, div) ->
		$(div).append("<ol class=\"hwstruct-obj\"></ol>")
		list = $(div).children("ol")
		for key,elem of obj
			list.append("<li><div class=\"hwstruct-obj-elem\"><div class=\"hwstruct-title\">#{key}:</div><div class=\"hwstruct-content\"></div></div></li>")
			this.dump_values(elem, list.children("li").last().children("div").last().children("div").last().get(0) )
		list.children('li:nth-child(odd)').addClass('hwodd');

	dump_number: (number, div) ->
		div.innerHTML = "#{number}"

	dump_string: (str, div) ->
		div.innerHTML = str

	dump_values: (values, div=null) ->
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
