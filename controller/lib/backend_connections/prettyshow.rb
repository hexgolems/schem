# encoding: utf-8
class String
  # rubocop: disable StringLiterals
  # colorizes string red
  def red
    colorize(self, "\e[1m\e[31m")
  end

  # colorizes string red
  def dark_red
    colorize(self, "\e[31m")
  end

  # colorizes string green
  def green
    colorize(self, "\e[1m\e[32m")
  end

  # colorizes string green
  def dark_green
    colorize(self, "\e[32m")
  end

  # colorizes string yellow
  def yellow
    colorize(self, "\e[1m\e[33m")
  end

  # colorizes string yellow
  def dark_yellow
    colorize(self, "\e[33m")
  end

  # colorizes string blue
  def blue
    colorize(self, "\e[1m\e[34m")
  end

  # colorizes string blue
  def dark_blue
    colorize(self, "\e[34m")
  end

  # colorizes string purple
  def pur
    colorize(self, "\e[1m\e[35m")
  end

  # colorizes string purple
  def dark_pur
    colorize(self, "\e[35m")
  end

  # colorizes string grey
  def grey
    colorize(self, "\e[1m\e[30m")
  end

  # colorizes string dark grey
  def dark_dark
    colorize(self, "\e[37m")
  end

  # colorizes a string with the given colorcode
  def colorize(text, color_code)
    "#{color_code}#{text}\e[0m"
  end
  # rubocop: enable StringLiterals
end
