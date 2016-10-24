require 'irb'

IRB.init_config nil
IRB.conf[:PROMPT_MODE] = :DEFAULT
IRB.conf[:VERBOSE] = false

def IRB.Output
  IRB.conf[:OUTPUT]
end

def IRB.evaluate_string string
  IRB.conf[:PROMPT_MODE] = :DEFAULT
  IRB.conf[:VERBOSE] = false
  IRB.conf[:OUTPUT] = []

  irb = IRB::Irb.new nil, StringInputMethod.new(string + "\n")
  IRB.conf[:MAIN_CONTEXT] = irb.context
  irb.eval_input
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
  def output_value
    context = IRB.CurrentContext
    IRB.Output << [ :stdout, context.return_format % context.inspect_last_value ]
  end

  def print *args
    IRB.Output << [ :stderr, args.join, caller ]
  end

  def printf format, *args
    IRB.Output << [ :stderr, format % args, caller ]
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
