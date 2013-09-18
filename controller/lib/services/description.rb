# TODO document me
module Schem

  # TODO document me
  class DescriptionService < BaseService

    attr_reader :mxcsr_description, :instructions

    def initialize(*args)
      super
      @mxcsr = {
        IE: "Invalid Operation Flag",
        DE: "Denormal Flag",
        ZE: "Divide By Zero Flag",
        OE: "Overflow Flag",
        UE: "Underflow Flag",
        PE: "Precision Flag",
        DAZ: "Denormals Are Zero",
        IM: "Invalid Operation Mask",
        DM: "Denormal Mask",
        ZM: "Divide By Zero Mask",
        OM: "Overflow Mask",
        UM: "Underflow Mask",
        PM: "Precision Mask",
        RN: "Round To Nearest",
        RZ: "Round To Zero",
        "R-".to_sym => "Round Negative",
        "R+".to_sym => "Round Positive",
        FZ: "Flush To Zero"
      }
      @rflags = {
        CF: "Carry flag",
        PF: "Parity flag",
        AF: "Adjust flag",
        ZF: "Zero flag",
        SF: "Sign flag",
        TF: "Trap flag (single step)",
        IF: "Interrupt enable flag",
        DF: "Direction flag",
        OF: "Overflow flag",
        ID: "Able to use CPUID instruction"
      }
      path = File.join(File.dirname(__FILE__),"../x86_instr_desc.txt") #TODO make this depend on object service & proper path
      lines = File.read(path).lines
      @instructions = lines.inject({}){|h,line| op,desc = line.strip.split(/[ \t]/,2); h[op.strip]=desc.strip; h}
    end

  end
  register_service(:desc, DescriptionService)
end
