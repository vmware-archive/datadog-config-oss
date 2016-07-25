require "erb"
require "erb_context"

class Template
  def initialize(params)
    @template_file = params.fetch(:template_file)
    #@search_and_replace = params.fetch(:search_and_replace)
    @search_and_replace = build_search_and_replace(params.fetch(:search_and_replace))
  end

  def build_search_and_replace(original)
    results = {}
    original.each do |key, value|
      results[key] = {
        regex: regex_of_value(value),
        replace_string: replace_string_of_value(value)
      }
    end
    results
  end

  def regex_of_value(value)
    string = case value
      when String
        value
      when Hash
        value[:regex]
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
        value[:replace_string]
      else
        raise "I Can't computer"
    end
  end

  def to_erb_from_string(str)
    @search_and_replace.each do |k,v|
      str.gsub!(v[:regex], "<%= #{k} %>" )
    end

    str
  end

  def to_string_from_erb(str)
    # this returns the binding as it exists from the context's perspective
    # so all of the properties set on the ErbContext instance are exposed as
    # variables in the binding and therefore the ERB
    # TL;DR Magic.
    context = ErbContext.new(@search_and_replace)
    context_binding = context.instance_eval { binding }
    erb = ERB.new(str)
    output = erb.result(context_binding)

    return output

    # TODO: thresholds_file_path = thresholds_file(template_path)
    # if File.exists? thresholds_file_path
    #   context.thresholds = thresholds_for_yaml_file(thresholds_file_path)
    # end
  end
end
