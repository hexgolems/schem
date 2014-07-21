#  encoding: utf-8

require_relative './breakpointwrapper.rb'
require_relative './controlwrapper.rb'
require_relative './callbackwrapper.rb'
require_relative './memorywrapper.rb'
require_relative './registerwrapper.rb'
require_relative './imagesectionwrapper.rb'

silence_warnings do
  require 'pry'
end

module Schem
  module PinDebuggerApi
    include BreakpointWrapper
    include RegisterWrapper
    include ControlWrapper
    include MemoryWrapper
    include CallbackWrapper
    include ImageSectionWrapper

    def init_dbg_api
      @on_stop_callbacks = Set.new
      @on_execute_callbacks = Set.new
      @on_quit_callbacks = Set.new
      @mapped_images = {}
      @shared_objects = []

      @event_handler = ThreadedEventHandler.new do |msg|
        if msg.value['event'] == 'stopped'
          if msg.value['info']['reason'] =~ /exit/
            @on_quit_callbacks.each { |cb| cb.call(msg.value['info']) }
          else
            @on_stop_callbacks.each { |cb| cb.call(msg.value['info']) }
          end
        elsif msg.value['event'] == 'running'
          @on_execute_callbacks.each { |cb| cb.call(msg.value['info']) }
        end
      end

      @debugger.register_event_handler('exec', @event_handler)

      init_bp_wrapper
      init_reg_wrapper
      init_control_wrapper
      init_callback_wrapper
      init_memory_wrapper
      init_image_section_wrapper
    end

    def internal_address_mapped?(address)
      assert { address.is_a? Integer }
      sections = internal_mem_mappings
      sections.each do |section|
        return true if section.from <= address && address <= section.to
      end
      false
    end

    def internal_list_shared_objects
      max_tries(3, 0.01, 'pin_api:internal_list_shared_objects') do
        res = @debugger.send_cli_string('info share', /\AFrom\s+To\s+Syms Read\s+Shared Object Library\\n\Z/)
        assert { res.is_a?(String) && res != '' }
        matches = res.split('\n').map do |x|
          /(?<shared_object>\/.*)/.match(x)
        end
        assert('no shared objects') { matches.length > 0 }
        shared_objects = matches.compact.map { |x| x['shared_object'] }
        @shared_objects = shared_objects
        return shared_objects
      end
    end

    # creates a new breakpoint
    # @param address [Integer] the address where to place the breakpoint, mode
    # [String] the breakpoint mode, can be:
    # '' software breakpoint,
    # 'hardware' for hardware breakpoint,
    # @return
    # raise
    def internal_bp_create(address, mode = 'software')
      assert { address.is_a? Integer }
      mode = mode.to_s
      # is_mapped = internal_address_mapped?(address)
      # assert('unable to set breakpoint at unmapped address '){ is_mapped }
      res = internal_bp_create_helper(address, mode)
      return Breakpoint.new(:hardware, true, address, res['number']) if mode == 'hardware'
      return Breakpoint.new(:software, true, address, res['number']) if mode == 'software'
      fail NotImplementedError.new("invalid breakpoint mode: #{mode}")
    end

    def internal_bp_create_helper(address, mode)
      max_tries(3, 0.01, 'pin_api:internal_bp_create_helper') do
        case mode.to_s
        when 'software' then res = @debugger.send_mi_string("-break-insert *#{address}")
        when 'hardware' then res = @debugger.send_mi_string("-break-insert -h *#{address}")
        else fail NotImplementedError.new("invalid breakpoint mode: #{mode}")
        end
        assert('pin was unable to add a breakpoint') { res.content_type == 'done' }
        return res.value['bkpt']
      end
    end

    # creates a new watchpoint
    # @param address [Integer] the address where to place the breakpoint, mode
    # [String] the watchpoint mode, which can be:
    # 'regular' the watchpoint created is a regular watchpoint, i.e., it will
    # trigger when the memory location is accessed for writing
    # 'read' the watchpoint created is a read watchpoint, i.e., it will
    # trigger only when the memory location is accessed for reading
    # 'access' create an access watchpoint, i.e., a watchpoint that triggers
    # either on a read from or on a write to the memory location
    # @return [Breakpoint]
    # raise
    def internal_wp_create(address, mode = 'regular')
      assert { address.is_a? Integer }
      # is_mapped = internal_address_mapped?(address)
      # assert('unable to set watchpoint at unmapped address '){ is_mapped }
      mode = mode.to_s
      short_form = { 'regular' => :wp_regular, 'read' => :wp_read, 'access' => :wp_access }
      assert('invalid watchpoint mode') { short_form.include?(mode) }
      res = internal_wp_create_helper(address, mode.to_s)
      Breakpoint.new(short_form[mode], true, address, res['number'])
    end

    def internal_wp_create_helper(address, mode)
      mode, res = mode.to_s, ''
      max_tries(3, 0.01, 'pin_api:internal_wp_create_helper') do
        short_form = { 'regular' => '', 'read' => '-r', 'access' => '-a' }
        res = @debugger.send_mi_string("-break-watch #{short_form[mode]} *#{address}")
        assert('unable to add a watchpoint') { res.content_type == 'done' }
      end
      short_form = { 'regular' => 'wpt', 'read' => 'hw-rwpt', 'access' => 'hw-awpt' }
      res.value[short_form[mode]]
    end

    # TODO add tracepoints support?

    # deletes a breakpoint
    # @param breakpoint [Breakpoint]
    # @return true if breakpoint was delete
    # raise "not a breakpoint" if @param is not a breakpoint, "unable to delete
    # a valid breakpoint +..." if breakpoint couldn't be deleted within 3 tries
    def internal_bp_delete(bp)
      # if it is not a breakpoint let's throw an exception
      assert('not a breakpoint') { bp.is_a? Breakpoint }
      max_tries(3, 0.01, 'pin_api:internal_bp_delete') do
        res = @debugger.send_mi_string("-break-delete #{bp.internal_representation}")
        # raise an exception when we are unable to delete a valid breakpoint
        assert('unable to delete a valid breakpoint') { res.content_type == 'done' }
        # everything went find, so let's return true
        return true
      end
    end

    # returns an Array of Breakpoints
    # @param none
    # @return Array [Breakpoints]
    # raise "unable to extract breakpoint list" if pin failed to give us the bplist after 3 tries
    def internal_bp_list
      max_tries(3, 0.01, 'pin_api:internal_bp_list') do
        res = @debugger.send_mi_string('-break-list')
        assert('unable to extract breakpoint list') { res.content_type == 'done' }
        bplist = res.value['BreakpointTable']['body']
        assert('pin did not return a breakpoint list') { !bplist.nil? }
        return bplist.each_pair.map do |_name, bp|
          Breakpoint.new(:unknown, :unknown, :unknown, bp['number'])
        end
      end
    end

    # checks that the register length didn't change (pin sometimes sends to few registers)
    # @param
    # @return
    # raise
    def internal_check_register_length(length)
      @number_of_registers ||= length
      @number_of_registers = length if length > @number_of_registers
      assert('check_register_length failed') { length == @number_of_registers }
    end

    # lists all registers and their content
    # @param
    # @return
    # raise
    def internal_registers
      @register_names ||= internal_get_register_names
      register_values = internal_get_register_values
      @register_names.each_with_index.reduce({}) do |acc, (name, index)|
        acc[name] = Schem::Register.new(name, register_values[index])
        acc
      end
    end

    # PRIVATE! - Retrieve the values of the registers
    # @param
    # @return
    # raise
    def internal_get_register_values
      max_tries(3, 0.01, 'pin_api:internal_get_register_values') do
        res = @debugger.send_mi_string('-data-list-register-values x')
        assert('unable to get register values') { res.content_type == 'done' }
        regs = res.value['register-values']
        internal_check_register_length(regs.length)
        return regs
      end
    end
    private :internal_get_register_values

    # PRIVATE! - Retrieve the names of the registers
    # @param
    # @return
    # raise
    def internal_get_register_names
      max_tries(3, 0.01, 'pin_api:internal_get_register_names') do
        res = @debugger.send_mi_string('-data-list-register-names')
        assert('unable to get register names ') { res.content_type == 'done' }
        regs = res.value['register-names']
        # And because pin is  ŝ̜̟̜͇ͨͧ͋h̴̻̘̩͙̪͔ͧͯͤͦͯ̚ị̡̘̜̼̃̃ͨtͬ̈́
        regs = regs.select { |x| x != '' }
        internal_check_register_length(regs.length)
        return regs
      end
    end
    private :internal_get_register_names

    # set a register to a specific value, value has to be >= 0
    #
    # @param register_name [Symbol] value [Integer]
    # @return true on success
    # raise 'unable to set register...' if pin was unable to set the register
    # to the value
    def internal_set_register(name, value)
      @register_names ||= internal_get_register_names
      name = name.to_s
      assert { value.is_a? Integer }
      assert { value >= 0 }
      assert('unknown register') { @register_names.include? name }
      reg_number = @register_names.index(name)
      max_tries(3, 0.01, 'pin_api:internal_set_register') do
        res = @debugger.send_mi_string("-data-write-register-values x #{reg_number} #{value}")
        assert('unable to set register') { res.content_type == 'done' }
        regs = internal_registers
        assert { regs[name].value['value'].to_gdbi == value }
        return true
      end
    end

    # returns a binary string containing the memory
    # @param
    # @return
    # raise
    def internal_mem_read(address, size)
      assert { address.is_a? Integer }
      # is_mapped = internal_address_mapped?(address)
      # assert("mem not mapped at address: #{address}") { is_mapped }
      max_tries(3, 0.01, 'pin_api:internal_mem_read') do
        # -data-read-memory -- address format size_of_byte_to_read count nr-rows nr-cols
        req =  "-data-read-memory-bytes #{address} #{size} "
        res = @debugger.send_mi_string(req)
        assert("unable to read memory wit #{req.inspect}") { res.content_type == 'done'  }
        res = res.value['memory'].first['contents'].scan(/../).map { |b| b.to_i(16).chr }.join('')
        assert('pin returned a wrong amount of bytes') { res.length == size }
        return res
      end
    end

    # writes a  binary string to the specified address
    # @param [Integer] address the address to write to
    # @param [String] contents the string that will be written
    # @return true if it was able to write the string, raises otherwise
    # raise
    def internal_mem_write(address, contents)
      # is_mapped = internal_address_mapped?(address)
      # assert('cannot write to unmapped memory') { is_mapped }
      contents = contents.each_byte.map { |x| x.to_s(16).rjust(2, '0') }.join
      max_tries(3, 0.01, 'pin_api:internal_mem_write') do
        # -data-write-memory-bytes address contents
        res = @debugger.send_mi_string("-data-write-memory-bytes #{address} #{contents}")
        assert('unable to write memory bytes') { res.content_type == 'done' }
        return true
      end
    end

    # returns a list of sections
    # @return [[MemorySection]] mem_sections if it was able to get the mem mappings, raises otherwise
    # raise
    def internal_get_mapped_images
      old_shared_objects = @shared_objects
      if old_shared_objects == internal_list_shared_objects && !@mapped_images.empty?
        return @mapped_images
      else
        max_tries(3, 0.01, 'pin_api:internal_get_mapped_images') do
          res = @debugger.send_cli_string('maint info sections ALLOBJ', /Exec/)
          assert { res.is_a?(String) && res != '' }
          matches = res.split('\n').map do |x|
            /(?<start>0x[a-fA-F0-9]+)->(?<end>0x[a-fA-F0-9]+)\s+at\s+(?<at>0x[a-fA-F0-9]+):\s+(?<name>\.[a-zA-Z\-\._]+)\s+(?<flags>.*)/.match(x) || /\s+Object\s+file:\s+(?<object_file>.+)\s+at\s+(?<at>0x[a-fA-F0-9]+)\s*/.match(x) || /\s+Object\s+file:\s+(?<object_file>.+)/.match(x)
          end
          assert('no sections mapped') { matches.length > 0 }
          object_file = ''
          mapped_images = {}
          matches.compact.map do |x|
            if x.names.include? 'object_file'
              object_file = x['object_file']
            else
              from = x['start'].to_gdbi - x['at'].to_gdbi
              to = x['end'].to_gdbi - 1
              mapped_images[(from..to)] = object_file
            end
          end
          # I guess this line needs some comment ;)
          # first all mapped_images will be grouped by their value so that we
          # group all the "segments" of an image are under the same key, then
          # we map the whole thing so that we get name_of_image -> start..end
          mapped_images = mapped_images.each_pair.group_by { |_, x| x }.map_values { |_k, v| v.first.first.min .. v.last.first.max }
          return mapped_images
        end
      end
    end

    # image id == path
    def internal_get_image_bin(path)
      # TODO if not present locally get it via pin
      File.read(path)
    end

    # returns a list of mapped memory chunks
    # @return [[MemorySection]] mem_sections if it was able to get the mem mappings, raises otherwise
    # raise
    # FIXME
    def internal_mem_mappings
      max_tries(3, 0.01, 'pin_api:internal_mem_mappings') do
        res = @debugger.send_pin_string('monitor mappings')
        assert { res.is_a?(String) && res != '' }
        # Delete the newline, the newline is needed for some reason...
        res = res[0..-3] if res[-2..-1] == '\\n'
        # substitute the single quotes to quotes
        res = res.gsub("'", '"')
        res = JSON.parse(res)
        # TODO maybe switch to the more finegrained version of memory sections
        # right now only few big sections are formed, to inspect this uncomment the following code:
        # binding.dbg
        # res.inspect
        sections = res.map{|k, v|
          from = v['start']
          to = v['end'] - 1
          length = to - from
          object_file = k
          offset = nil
          MemorySection.new(from, to, length, offset, object_file)
        }
        return sections
      end
    end

    # (re)starts the program
    # @param
    # @return
    # raise
    def internal_restart
      @debugger.restart
    end

    # closes the debugging session, terminating the inferior
    # @param
    # @return
    # raise
    def internal_quit
      # TODO
    end

    # steps over enventual calls
    # @param
    # @return
    # raise
    def internal_step_over
      max_tries(3, 0.01, 'pin_api:step_over') do
        res = @debugger.send_mi_string('-exec-next-instruction')
        assert('unable to run command -exec-next-instruction') { res.content_type == 'running' }
        return true
      end
    end

    # steps into enventual calls
    # @param none
    # @return
    # raise
    def internal_step_into
      max_tries(3, 0.01, 'pin_api:internal_step_into') do
        res = @debugger.send_mi_string('-exec-step-instruction')
        assert('unable to run command -exec-step-instruction') { res.content_type == 'running' }
        return true
      end
    end

    # continues the execution of the process
    # @param
    # @return
    # raise
    def internal_continue
      max_tries(3, 0.01, 'pin_api:internal_continue') do
        res = @debugger.send_mi_string('-exec-continue')
        assert('unable to run command -exec-continue') { res.content_type == 'running' }
        return true
      end
    end

    # calls the block after a stop
    # @param
    # @return
    # raise
    def internal_on_stop(&callback)
      @on_stop_callbacks.add callback
    end

    # calls the given block if the inferior starts executing
    # @param
    # @return
    # raise
    def internal_on_execute(&callback)
      c = caller
      binding.dbg unless callback
      @on_execute_callbacks.add callback
    end

    # calls the given block if the debugger quits (e.g. if the current process termiantes / is terminated)
    # @param
    # @return
    # raise
    def internal_on_quit(&callback)
      @on_quit_callbacks.add callback
    end
  end
end
