# TODO document me
module Schem

  # TODO document me
  class RegisterService < BaseService

    EFLAGS = {CF: 0, PF: 2, AF: 4, ZF: 6, SF: 7, TF: 8, IF: 9, DF: 10, OF: 11, ID: 21}
attr_reader :general_purpose, :segment, :xmm, :ymm, :ymmh, :floating_point, :reg_length, :reg_length32, :reg_length64, :old_ip

    def toggle_flag(flag)
      return unless EFLAGS.include? flag
      eflags = get_value(:eflags)
      pos = EFLAGS[flag]
      val = eflags[pos]
      eflags ^= 2 ** pos
      set(:eflags, eflags)
    end

    def initialize(*args)
      super
      register(:acc,            { [:x86, 64] => :rax, [:x86, 32] => :eax })
      register(:base,           { [:x86, 64] => :rbx, [:x86, 32] => :ebx })
      register(:count,          { [:x86, 64] => :rcx, [:x86, 32] => :ecx })
      register(:data,           { [:x86, 64] => :rdx, [:x86, 32] => :edx })
      register(:src_index,      { [:x86, 64] => :rsi, [:x86, 32] => :esi })
      register(:source,         { [:x86, 64] => :rsi, [:x86, 32] => :esi })
      register(:dest_index,     { [:x86, 64] => :rdi, [:x86, 32] => :edi })
      register(:destination,    { [:x86, 64] => :rdi, [:x86, 32] => :edi })
      register(:base_ptr,       { [:x86, 64] => :rbp, [:x86, 32] => :ebp })
      register(:stack,          { [:x86, 64] => :rsp, [:x86, 32] => :esp })
      register(:pc,             { [:x86, 64] => :rip, [:x86, 32] => :eip })
      register(:ip,             { [:x86, 64] => :rip, [:x86, 32] => :eip })
      publish(:registers) { nil }

      @general_purpose = {
        64 => {
          rax: {rax: (0..63), eax: (0..31), ax: (0..15), ah: (8..15), al: (0..7)},
          rbx: {rbx: (0..63), ebx: (0..31), bx: (0..15), bh: (8..15), bl: (0..7)},
          rcx: {rcx: (0..63), ecx: (0..31), cx: (0..15), ch: (8..15), cl: (0..7)},
          rdx: {rdx: (0..63), edx: (0..31), dx: (0..15), dh: (8..15), dl: (0..7)},
          rbp: {rbp: (0..63), ebp: (0..31), bp: (0..15), bpl: (0..7)},
          rsi: {rsi: (0..63), esi: (0..31), si: (0..15), sil: (0..7)},
          rdi: {rdi: (0..63), edi: (0..31), di: (0..15), dil: (0..7)},
          rsp: {rsp: (0..63), esp: (0..31), spl: (0..7)},
          # R8 (qword), R8D (lower dword), R8W (lowest word), R8B (lowest byte MASM style, Intel style R8L)
          r8:  {r8: (0..63), r8d: (0..31), r8w: (0..15), r8l: (0..7)},
          r9:  {r9: (0..63), r9d: (0..31), r9w: (0..15), r9l: (0..7)},
          r10: {r10: (0..63), r10d: (0..31), r10w: (0..15), r10l: (0..7)},
          r11: {r11: (0..63), r11d: (0..31), r11w: (0..15), r11l: (0..7)},
          r12: {r12: (0..63), r12d: (0..31), r12w: (0..15), r12l: (0..7)},
          r13: {r13: (0..63), r13d: (0..31), r13w: (0..15), r13l: (0..7)},
          r14: {r14: (0..63), r14d: (0..31), r14w: (0..15), r14l: (0..7)},
          r15: {r15: (0..63), r15d: (0..31), r15w: (0..15), r15l: (0..7)}
        },
      32 => {
          eax: { eax: (0..31), ax: (0..15), ah: (8..15), al: (0..7)},
          ebx: { ebx: (0..31), bx: (0..15), bh: (8..15), bl: (0..7)},
          ecx: { ecx: (0..31), cx: (0..15), ch: (8..15), cl: (0..7)},
          edx: { edx: (0..31), dx: (0..15), dh: (8..15), dl: (0..7)},
          ebp: { ebp: (0..31), bp: (0..15), bpl: (0..7)},
          esi: { esi: (0..31), si: (0..15), sil: (0..7)},
          edi: { edi: (0..31), di: (0..15), dil: (0..7)},
          esp: { esp: (0..31), spl: (0..7)},
        }
      }
      @instruction_pointer = { 64 => { rip: (0..63) }, 32 => { eip: (0..32) } }
      @segment = {
        cs: {cs: (0..63)},
        ss: {ss: (0..63)},
        ds: {ds: (0..63)},
        es: {es: (0..63)},
        fs: {fs: (0..63)},
        gs: {gs: (0..63)},
      }
      @floating_point = {
        st0: {st0: (0..1)},
        st1: {st1: (0..1)},
        st2: {st2: (0..1)},
        st3: {st3: (0..1)},
        st4: {st4: (0..1)},
        st5: {st5: (0..1)},
        st6: {st6: (0..1)},
        st7: {st7: (0..1)},
        fctrl: {fctrl: (0..1)},
        fstat: {fstat: (0..1)},
        ftag: {ftag: (0..1)},
        fiseg: {fiseg: (0..1)},
        fioff: {fioff: (0..1)},
        foseg: {foseg: (0..1)},
        fooff: {fooff: (0..1)},
        fop: {fop: (0..1)}
      }
      @xmm = {
        32 => {
          xmm0: {xmm0: (0..1)},
          xmm1: {xmm1: (0..1)},
          xmm2: {xmm2: (0..1)},
          xmm3: {xmm3: (0..1)},
          xmm4: {xmm4: (0..1)},
          xmm5: {xmm5: (0..1)},
          xmm6: {xmm6: (0..1)},
          xmm7: {xmm7: (0..1)},
        },
        64 => {
          xmm0: {xmm0: (0..1)},
          xmm1: {xmm1: (0..1)},
          xmm2: {xmm2: (0..1)},
          xmm3: {xmm3: (0..1)},
          xmm4: {xmm4: (0..1)},
          xmm5: {xmm5: (0..1)},
          xmm6: {xmm6: (0..1)},
          xmm7: {xmm7: (0..1)},
          xmm8: {xmm8: (0..1)},
          xmm9: {xmm9: (0..1)},
          xmm10: {xmm10: (0..1)},
          xmm11: {xmm11: (0..1)},
          xmm12: {xmm12: (0..1)},
          xmm13: {xmm13: (0..1)},
          xmm14: {xmm14: (0..1)},
          xmm15: {xmm15: (0..1)},
        }
      }
      @mm = {
        mm0: {mm0: (0..64)},
        mm1: {mm1: (0..64)},
        mm2: {mm2: (0..64)},
        mm3: {mm3: (0..64)},
        mm4: {mm4: (0..64)},
        mm5: {mm5: (0..64)},
        mm6: {mm6: (0..64)},
        mm7: {mm7: (0..64)},
      }
      @ymm = {
        32 => {
          ymm0:  {ymm0h: (0..1), ymm0: (0..1)},
          ymm1:  {ymm1h: (0..1), ymm1: (0..1)},
          ymm2:  {ymm2h: (0..1), ymm2: (0..1)},
          ymm3:  {ymm3h: (0..1), ymm3: (0..1)},
          ymm4:  {ymm4h: (0..1), ymm4: (0..1)},
          ymm5:  {ymm5h: (0..1), ymm5: (0..1)},
          ymm6:  {ymm6h: (0..1), ymm6: (0..1)},
          ymm7:  {ymm7h: (0..1), ymm7: (0..1)},
        },
        64 => {
          ymm0:  {ymm0h: (0..1), ymm0: (0..1)},
          ymm1:  {ymm1h: (0..1), ymm1: (0..1)},
          ymm2:  {ymm2h: (0..1), ymm2: (0..1)},
          ymm3:  {ymm3h: (0..1), ymm3: (0..1)},
          ymm4:  {ymm4h: (0..1), ymm4: (0..1)},
          ymm5:  {ymm5h: (0..1), ymm5: (0..1)},
          ymm6:  {ymm6h: (0..1), ymm6: (0..1)},
          ymm7:  {ymm7h: (0..1), ymm7: (0..1)},
          ymm8:  {ymm8h: (0..1), ymm8: (0..1)},
          ymm9:  {ymm9h: (0..1), ymm9: (0..1)},
          ymm10: {ymm10h: (0..1), ymm10: (0..1)},
          ymm11: {ymm11h: (0..1), ymm11: (0..1)},
          ymm12: {ymm12h: (0..1), ymm12: (0..1)},
          ymm13: {ymm13h: (0..1), ymm13: (0..1)},
          ymm14: {ymm14h: (0..1), ymm14: (0..1)},
          ymm15: {ymm15h: (0..1), ymm15: (0..1)},
        }
      }
      @reg_ranges64 = [@general_purpose[64], @instruction_pointer[64], @segment, @floating_point, @xmm, @ymm].inject({}) { |h,e| h.merge! e; h}.flatten_hash
      @reg_ranges32 = [@general_purpose[32], @instruction_pointer[32], @segment].inject({}) { |h,e| h.merge! e; h}.flatten_hash
      @reg_length64 = @reg_ranges64.map_values{ |k,v| v = v.size }
      @reg_length32 = @reg_ranges32.map_values{ |k,v| v = v.size }
      @reg_length = {
        32 => @reg_length32,
        64 => @reg_length64,
      }
      @mxcsr = {
        FZ: at_i(15), "R+".to_sym => at_i(14), "R-".to_sym => at_i(13),
        RZ: lambda{|int| (int[13]==1 && int[14]==1) ? 1 : 0}, RN: lambda{|int| (int[13]==0 && int[14]==0) ? 1 : 0},
        PM: at_i(12), UM: at_i(11), OM: at_i(10), ZM: at_i(9), DM: at_i(8), IM: at_i(7),
        DAZ: at_i(6), PE: at_i(5), UE: at_i(4), OE: at_i(3), ZE: at_i(2), DE: at_i(1), IE: at_i(0)
      }
    end

    def x86_32_regs
        return {
        general_purpose: reg_as_hash(@general_purpose[32]),
        IP: get_value_hex(:eip),
        flags: eflags_as_hash,
        segment: reg_as_hash(@segment),
        floating_point: reg_as_hash(@floating_point),
        mxcsr: mxcsr_as_hash,
        mm: reg_as_hash(@mm),
        xmm: reg_as_hash(@xmm[32]),
        ymm: reg_as_hash(@ymm[32])
        }
    end

    def x86_64_regs
        return {
        general_purpose: reg_as_hash(@general_purpose[64]),
        IP: get_value_hex(:rip),
        flags: eflags_as_hash,
        segment: reg_as_hash(@segment),
        floating_point: reg_as_hash(@floating_point),
        mxcsr: mxcsr_as_hash,
        xmm: reg_as_hash(@xmm),
        ymm: reg_as_hash(@ymm),
      }
    end

    def reg_as_hash(reg)
      reg.map_values do |reg_name, reg_val|
        reg_val.map_values do |sub_reg_name, sub_reg_val|
          unless registers
            next "nil"
          end
          val = get_value_hex sub_reg_name if sub_reg_name != :value
          val = get_value_hex reg_name if sub_reg_name == :value
          val
        end
      end
    end

    def at_i(index)
      return lambda { |int| int[index] }
    end

    def mxcsr_as_hash
      mxcsr = get_value(:mxcsr)
      mxcsr_hash = {}
      @mxcsr.each_pair do |name,getter|
        unless mxcsr
          mxcsr_hash[name] = "nil"
          next
        end
        mxcsr_hash[name] = getter.call(mxcsr)
      end
      return mxcsr_hash
    end

    def eflags_as_hash
      eflags = get_value(:eflags)
      eflags_hash = {}
      EFLAGS.each do |(name, index)|
        unless eflags
          eflags_hash[name] = "nil"
          next
        end
        eflags_hash[name] = eflags[index]
      end
      return eflags_hash
    end

    def set(name, value)
      value = srv.dbg.set_register(name, value)
      update
      return value
    end

    def get(name)
      registers[name.to_s] if registers
    end

    def get_value_hex(name)
      return registers[name.to_s].value['value'] if registers && registers[name.to_s]
      return nil
    end

    def get_value(name)
      return get_value_hex(name) if registers && (name.to_s =~ /\A[xy]mm\d+\Z/)
      return get_value_hex(name).to_gdbi if registers
    end

    def update
      publish(:registers) do
          new_registers = srv.dbg.registers
        if @old_registers != new_registers
          signal_waiting
          @old_registers = new_registers
        end
        new_registers
      end
      get_published_value(:registers)
    end

    def stop_callback
      @old_ip = ip
      update
    end

    def register(name, options)
      self_class = (class << self; self; end)
      self_class.send(:define_method, name) do
        return get_value(options[ [srv.obj.arch, srv.obj.word_width]])
      end
    end

  end
  register_service(:reg, RegisterService)
end
