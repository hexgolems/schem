# encoding: utf-8

class Time
  def self.to_config_s(val)
    val.to_s
  end

  def self.from_config_s(val)
    Time.parse(val)
  end
end
