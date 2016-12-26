require 'irb'

IRB.init_config nil
IRB.conf[:PROMPT_MODE] = :DEFAULT
IRB.conf[:VERBOSE] = false

class << IRB
  def Output
    conf[:OUTPUT]
  end

  def evaluate_string string
    conf[:PROMPT_MODE] = :DEFAULT
    conf[:VERBOSE] = false
    conf[:OUTPUT] = []

    irb = Irb.new nil, StringInputMethod.new(string + "\n")
    conf[:MAIN_CONTEXT] = irb.context
    irb.eval_input
  end

  alias_method :raw_irb_exit, :irb_exit

  def irb_exit irb, ret
    if IRB.Output
      ret
    else
      raw_irb_exit irb, ret
    end
  end
end

class IRB::WorkSpace
  def evaluate(context, statements, file = __FILE__, line = __LINE__)
    @after_ruby_debug_erb = false
    eval(statements, @binding, file, line)
  end

  FILTER_BACKTRACE_REGEX = /#{__FILE__}/
  def filter_backtrace backtrace
    return if @after_ruby_debug_erb
    if backtrace =~ FILTER_BACKTRACE_REGEX
      @after_ruby_debug_erb = true
      return
    else
      backtrace.sub(/:\s*in `irb_binding'/, '')
    end
  end
end

class IRB::Irb
  alias_method :raw_output_value, :output_value
  alias_method :raw_print, :print
  alias_method :raw_printf, :printf

  def output_value
    if IRB.Output
      context = IRB.CurrentContext
      IRB.Output << [ :stdout, context.return_format % context.inspect_last_value ]
    else
      raw_output_value
    end
  end

  def print *args
    if IRB.Output
      IRB.Output << [ :stderr, args.join, caller ]
    else
      raw_print *args
    end
  end

  def printf format, *args
    if IRB.Output
      IRB.Output << [ :stderr, format % args, caller ]
    else
      raw_printf format, *args
    end
  end
end

class StringInputMethod < StringIO
  attr_accessor :prompt
  def encoding; string.encoding end

  def gets
    line = super
    IRB.Output << [ :stdin, line ] if line
    line
  end
end
