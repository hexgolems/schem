$(document).ready ->
	$(".menu-bar").each ->
		foo = new ButtonBar(this)

class ButtonBar extends PluginAdapter

	constructor: (div) ->
			@div = div
			super "buttonsview"
			this.make_buttons()

		play: ->
			this.send_msg_data("play")
		stepi: ->
			this.send_msg_data("stepi")
		stepo: ->
			this.send_msg_data("stepo")
		restart: ->
			this.send_msg_data("restart")

	make_buttons: () ->
		$(@div).append("<button id='restart'></button>")
		$(@div).append("<button id='play'></button>")
		$(@div).append("<button id='stepi'></button>")
		$(@div).append("<button id='stepo'></button>")
		$(@div).find("button#restart").click () =>
			this.restart()
		$(@div).find("button#play").click () =>
			this.play()
		$(@div).find("button#stepi").click () =>
			this.stepi()
		$(@div).find("button#stepo").click () =>
			this.stepo()

