$(document).ready ->
	console.log("trying")
	$(".dialog-spawner").each ->
		foo = new DialogSpawner(this)

class DialogSpawner extends PluginAdapter

	constructor: (@div) ->
		super "dialogspawner"
		console.log("created dialog spawner")

	handle_msg: (data) ->
		if data.type == "alert"
			alert(data.text)
			this.send_msg_data( JSON.stringify({id: data.id}) )
		if data.type == "confirm"
			ok = confirm(data.text)
			this.send_msg_data( JSON.stringify({id: data.id, ok: ok}) )
		if data.type == "prompt"
			answer = prompt(data.text,data.default_value)
			this.send_msg_data( JSON.stringify({id: data.id, answer: answer}) )
		else
			console.log "unknown data", data
