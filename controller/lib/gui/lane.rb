# encoding: utf-8
require 'monitor'
require 'cgi'

module Schem
  class HexWidgetLane
    include MonitorMixin
    attr_accessor :srv

    def initialize(plugin)
      super()
      @plugin = plugin
      @srv = plugin.srv
      @colspan  = 1
    end

    def tag(name, text, color = nil)
      { name: name, text: text, color: color || Digest::MD5.hexdigest(name)[0..5] }
    end

    def repr(text, length = 1, tags = [], classes = [])
      tags = tags.map do |t|
        case t
          when Hash then t
          when Tag then tag(*t.as_json_array)
          else fail "expected a tag instead of #{t.inspect}"
        end
      end
      { length: length, text: text, tags: tags, additional_classes: classes }
    end

    def self.action(name, icon = nil, &block)
      @actions ||= {}
      @actions[name] = { icon: icon, label: name, callback: block }
    end

    def self.registered_actions
      @actions ||= {}
    end

    def perform_action(name, clicked, selected_range)
      synchronize do
        action = self.class.registered_actions[name]
        fail "unknown action #{name.inspect} for #{self.class}" unless action
        instance_exec(clicked, selected_range, &action[:callback])
      end
    end

    def get_available_actions
      self.class.registered_actions.values
    end

    def get_line_reprs(_address_range)
      fail 'Implement me in subclass'
      [some_repr, some_other_repr]
    end

    def render_tags(tags)
      return '', '' if tags.length == 0
      meta_data = []
      color = [0, 0, 0]
      tags.each do |tag|
        tag_colors = tag[:color][0..1], tag[:color][2..3], tag[:color][4..5]
        color.each_index { |i| color[i] += tag_colors[i].to_i(16) }
        meta_data << [tag[:name], tag[:text]]
      end
      original_background_color = '2702822'.scan(/../).map { |x| x.to_i(16) }
      avg_color = color.map.with_index { |c, i| ((c / tags.length) + original_background_color[i] * 1.5) / 2.5 }
      color_str = 'background-color: #' + avg_color.map { |c| c.to_i.to_s(16).rjust(2, '0') }.join
      # color_str+=";border-color: #" + color.map{|c| (c/(tags.length*1.2)).to_i.to_s(16).rjust(2,"0")}.join
      style = " style = '#{color_str}'"
      tags = " h='#{CGI.escape(JSON.dump(meta_data))}'"
      [style, tags]
    end

    def render_colgroup
      "<col span='#{self.class.get_colspan}' #{self.class.get_colstyle}/>"
    end

    def render_line(address_range)
      synchronize do
        line = ''
        a = address_range.min
        get_line_reprs(address_range).each do |repr|
          text = repr[:text] rescue binding.dbg
          len = repr[:length].to_i
          tags = repr[:tags]
          classes = repr[:additional_classes]
          style, tags = render_tags(tags)
          span = if len > 1 then " colspan=#{len}" else '' end
          classes = if  classes.length > 0 then " class='#{classes.join(' ')}'" else '' end
          line += "<td a=#{a.to_s(16)}#{span}#{style}#{tags}#{classes}>#{text}</td>"
          a += len
        end
        if a - address_range.min != self.class.get_colspan
          fail "missmatch number of colspans #{a - address_range.min} != #{self.class.get_colspan.inspect} from #{self.class}"
        end
        return line
      end
    end

    def update!
      @plugin.send_updated
    end

    def self.colspan(x)
      @colspan = x
    end
    def self.get_colspan
      @colspan || fail("colspan not initialized for #{self}")
    end
    def self.colstyle(x)
      @colstyle = x
    end
    def self.get_colstyle
      @colstyle ||= ''
    end
  end

  class AddressLane < HexWidgetLane
    colspan 1

    action 'add label' do |_clicked, selected|
      name = srv.dialog.prompt('Add label')['answer']
      ins = srv.disasm_cache.get(selected.first)
      range = ins.range if ins
      srv.tags.add(Schem::Tag.new(name, range, :user_label)) if range
      srv.tags.add(Schem::Tag.new(name, selected, :user_label)) unless range
      update!
    end

    action 'goto label' do |clicked, _|
      name = srv.dialog.prompt('Goto label')['answer']
      address = srv.tags.by_name(name).first.range.min if name
      @plugin.goto(address, 3, clicked.min) if address
      update!
    end

    action 'relative address' do |clicked_range, _selected_range|
      @relative_target = clicked_range.min
      update!
    end

    action 'relative address' do |clicked_range, _selected_range|
      @relative_target = clicked_range.min
      update!
    end

    action 'absolute address' do |_clicked_range, _selected_range|
      @relative_target = nil
      update!
    end

    def initialize(*args)
      super
      @relative_target = nil
    end

    def get_line_reprs(address_range)
      repr = ''
      if @relative_target
        repr = (address_range.min - @relative_target).hex_dump(8)
      else
        repr = address_range.min.hex_dump(8)
      end
      tags = srv.tags.by_address(address_range.min)
      labels = tags.select { |tag| tag.type == :label }.map(&:name).compact
      label = labels.map do |x|
        "<span title=\"#{Esc.h(x)}\">#{Esc.h(x.ellipsis(10))}</span>"
      end.join('<br>')
      repr = label if label.length > 0
      classes = ['address-lane']
      classes << 'hl-bp-color' if tags.any? { |t| t.type == :breakpoint }
      tags = []
      [repr(repr, 1, tags, classes)]
    end
  end

  class AsciiLane < HexWidgetLane
    colspan 1

    def get_line_reprs(address_range)
      res = []
      ranges = srv.mem.get_mapped_memory(address_range)
      ranges.each do |is_mapped, range|
        if is_mapped == :valid
          bytes = srv.mem.read_int_array(range.min, (range.max - range.min + 1), 8)
          string = ''
          bytes.each do |b|
            string += String.byte_repr(b.chr)
          end
          res << repr(string, 1)
        else
          res << repr('unmapped', 1)
        end
      end
      res
    end
  end

  class TagLane < HexWidgetLane
    colspan 1
    def get_line_reprs(address_range)
      tags = srv.tags.by_range(address_range).select { |t| t.name !~ /\.[0-9]+\Z/ }
      names = tags.map { |x| x.name.hover_ellipsis(10) }.join('<br>')
      tag_repr = tags.map { |t| tag(t.name, t.data[:info_string], t.data[:color]) }
      [repr(names, 1, tag_repr)]
    end
  end
end
