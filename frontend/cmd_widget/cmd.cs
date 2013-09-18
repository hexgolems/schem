$(document).ready ->
	console.log("trying")
	$(".gdb-controller-view").each ->
		foo = new CmdView(this)

class CmdView extends PluginAdapter

	constructor: (@div) ->
		super "cmdview"
		console.log("created cmdline")
		@div.innerHTML = "
			<input class = 'cv-line' type = 'text' ></input>
			<div class = 'cv-log'> </div>
		"
		@log = $(@div).children("div").first().get(0)
		@input = $(@div).children("input").first().get(0)
		$(@input).keyup (e) =>
			if e.keyCode == 13 #enter
				this.send_command(@input.value)
				@input.value = ""

	handle_msg: (data) ->
		if data["type"] == "update"
			this.add_msg(data["data"])
		else
			console.log "unknown data", data

	send_command: (cmd) ->
		this.send_msg_data( JSON.stringify({type: "cmd", line: cmd}) )
	
	add_msg: (msg) ->
		$(@log).prepend("<p class='cv-result'>#{msg}</p>")
