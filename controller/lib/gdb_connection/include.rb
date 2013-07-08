# encoding: utf-8
require 'pp'

class Numeric
  def to_gdbi
    return self
  end

  def to_gdbs(base=10)
    case base
    when 16 then return "0x"+self.to_s(16)
    when 10 then return self.to_s(10)
    when 8 then return "0"+self.to_s(8)
    else raise "unknown base #{base.inspect} for gdbi"
    end
  end
end

class String
    def to_gdbi
        return self.to_i(16) if self[0..1] == '0x'
        return self.to_i(8) if self[0] == '0'
        return self[0..-2].to_i(10) if self[-1] == '.'
        return self.to_i(10) if is_gdbi?
        raise "invlid gdbi #{self}"
    end

    def to_gdbs(base=10)
      raise "not a gdbi #{self.inspect}" unless is_gdbi?
      to_gdbi().to_gdbs(base64)
    end

    def is_gdbi?
        self =~ /^[ ]*[0-9]+(\.)?[ ]*$/ || self =~ /^[ ]*0x[0-9A-Fa-f]*[ ]*$/
    end
end

