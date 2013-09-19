var CmdView,
  __hasProp = Object.prototype.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

$(document).ready(function() {
  console.log("trying");
  return $(".gdb-controller-view").each(function() {
    var foo;
    return foo = new CmdView(this);
  });
});

CmdView = (function(_super) {

  __extends(CmdView, _super);

  function CmdView(div) {
    var _this = this;
    this.div = div;
    CmdView.__super__.constructor.call(this, "cmdview");
    console.log("created cmdline");
    this.div.innerHTML = "			<input class = 'cv-line' type = 'text' ></input>			<div class = 'cv-log'> </div>		";
    this.log = $(this.div).children("div").first().get(0);
    this.input = $(this.div).children("input").first().get(0);
    $(this.input).keyup(function(e) {
      if (e.keyCode === 13) {
        _this.send_command(_this.input.value);
        return _this.input.value = "";
      }
    });
  }

  CmdView.prototype.handle_msg = function(data) {
    if (data["type"] === "update") {
      return this.add_msg(data["data"]);
    } else {
      return console.log("unknown data", data);
    }
  };

  CmdView.prototype.send_command = function(cmd) {
    return this.send_msg_data(JSON.stringify({
      type: "cmd",
      line: cmd
    }));
  };

  CmdView.prototype.add_msg = function(msg) {
    return $(this.log).prepend("<p class='cv-result'>" + msg + "</p>");
  };

  return CmdView;

})(PluginAdapter);
