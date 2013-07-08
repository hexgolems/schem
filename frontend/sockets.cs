class PluginAdapter

	constructor: (@name) ->
		@queued =[] # a queue for all messages send befor the socket is opened sucessfully
		this.get_socket()

	get_socket: () ->
		@socket = new WebSocket("ws://localhost:8000/spawn_plugin/#{@name}")
		@socket.onopen = () =>
			@opened = true
			this.handle_open()
			for val, _ in @queued
				this.send_msg_data(val)

		@socket.onmessage = (msg) =>
			if msg.data == "ok"
				console.log "valid plugin"
			else if msg.data == "plugin not found"
				alert("unable to find the plugin #{@name} at the server")
			else
				data = JSON.parse(msg.data)
				this.handle_msg(data)

		@socket.onclose = () =>
			this.handle_close()

	send_msg_data: (send_data) =>
		console.log("send", send_data)
		if !@opened
			@queued.push send_data
		else
			@socket.send(send_data)

	handle_open: () -> #override to make a usable class
		console.log("openend controll socket")

	handle_close: () -> #override to make a usable class
		console.log("closed controll socket")

	handle_msg: (msg) -> #override to make a usable class
		console.log(msg)
