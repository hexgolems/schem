module Schem
  class Highlighter < BaseService
    def initialize(*args)
      super
      @default_classes = {
        number: number_regex
      }
    end

    def number_regex
      /0x[0-9a-fA-F]+|[0-9]+|[0-9a-fA-F]h/
    end

    def html(instr)
      tokens = tokenize(instr)
      tokens.map.with_index do |tok, i|
        classes = get_classes(tok, i)
        desc = get_description(tok) if i == 0
        classes_string = if classes.length > 0 then "class='#{classes.join(' ')}' " else '' end
        desc_string = if desc then "title='#{desc}' " else '' end
        string = classes_string + desc_string
        if string.length > 0
          next "<span #{string}>#{tok}</span>"
        else
          next tok
        end
      end.join('')
    end

    def get_matching(classes, token)
      classes.keys.select { |name| classes[name] =~ token }
    end

    def get_classes(token, i)
      arg_classes = get_matching(@arg_classes, token) if i >= 1
      instr_classes = get_matching(@instr_classes, token) if i == 0
      default_classes = get_matching(@default_classes, token)
      default_classes + (arg_classes || []) + (instr_classes || [])
    end

    def get_description(token)
      srv.desc.instructions[token.downcase.gsub(' ', '')]
    end
  end

  class X68Highlighter < Highlighter
    def initialize(*args)
      super
      @arg_classes = {
        register: register_regex
      }
      @instr_classes = {
        call: call_regex,
        jump: jump_regex,
        arith: arith_regex,
        logic: logic_regex,
        mov: mov_regex,
        float: float_regex
      }
    end

    def register_regex
      /\A([re]?[abcd]x|([abcd][hl])|
       [re]?(bp|si|di)|(bp|si|di)l?|
       rsp|esp|spl|
       r([89]|1[0-5])[dwl]?|
       [csdefg]s|[er]ip)\Z/x
    end

    def jump_regex
      /\Aj\w{1,4}|loop\w*\Z/
    end

    def call_regex
      /\Acall|ret|retn|int|syscall|sysenter|sysret|sysexit\Z/
    end

    def arith_regex
      /\Aadd|mul|imul|div|idiv|neg|not|adc|sbb|inc|dec|lea|aa[adms]|rcl|rcr|ro[rl]|sa[lr]|sh[lr]\Z/
    end

    def logic_regex
      /\Aand|or|xor|not|test\Z/
    end

    def mov_regex
      /mov|store|push|pop|load/
    end

    def float_regex
      /\Af\w+\Z/
    end

    def tokenize(line)
      line.scan(/rep\s*\w+|0x[0-9a-fA-F]+|[re]?[abcd]x|[\[\]+\-*,]|\w+|\s+/)
    end
  end

  register_service(:x86highlight, X68Highlighter)
end
