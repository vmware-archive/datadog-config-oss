require "erb"
require "erb_context"

class Template
  def initialize(params)
    build_search_and_replace(params.fetch(:search_and_replace))
    @erb_value = params.fetch(:erb, nil)
    @string_value = params.fetch(:string, nil)
  end

  def build_search_and_replace(original)
    @search = {}
    @replace = {}
    original.each do |key, value|
      @search[key] = regex_of_value(value)
      @replace[key] = replace_string_of_value(value)
    end
  end

  def regex_of_value(value)
    string = case value
      when String
        value
      when Hash
        value[:search]
      else
        raise "I Can't computer"
    end
    Regexp.new(string)
  end

  def replace_string_of_value(value)
    case value
      when String
        value
      when Hash
        value[:replace]
      else
        raise "I Can't computer"
    end
  end

  def erb
    @erb_value ||= to_erb
  end

  def to_erb
    @search.each do |k,v|
      string.gsub!(v, "<%= #{k} %>" )
    end
    string
  end

  def string
    @string_value ||= to_string
  end

  def to_string
    # this returns the binding as it exists from the context's perspective
    # so all of the properties set on the ErbContext instance are exposed as
    # variables in the binding and therefore the ERB
    # TL;DR Magic.
    context = ErbContext.new(@replace)
    context_binding = context.instance_eval { binding }
    yerb = ERB.new(erb)
    output = yerb.result(context_binding)

    return output

    # TODO: thresholds_file_path = thresholds_file(template_path)
    # if File.exists? thresholds_file_path
    #   context.thresholds = thresholds_for_yaml_file(thresholds_file_path)
    # end
  end
end
