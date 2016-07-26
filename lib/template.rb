require "erb"
require "erb_context"
require 'active_support/core_ext/hash/indifferent_access'

class Template
  def initialize(params)
    build_search_and_replace(params.fetch(:search_and_replace))
    @erb_value = params.fetch(:erb, nil)
    @string_value = params.fetch(:string, nil)
  end

  def build_search_and_replace(hash)
    @search = {}
    @replace = {}

    hash = hash.with_indifferent_access
    hash.each do |key, value|
      @search[key.to_sym] = regex_of_value(value)
      @replace[key.to_sym] = replace_string_of_value(value)
    end
  end

  def regex_of_value(value)
    shwing = case value
      when String
        value
      when Hash
        value[:search]
      else
        raise "I Can't computer"
    end
    Regexp.new(shwing)
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
    shtring = string.dup
    @search.each do |k,v|
      shtring.gsub!(v, "<%= #{k} %>" )
    end
    shtring
  end

  def string
    @string_value ||= to_string
  end

  def to_string
    # this returns the binding as it exists from the context's perspective
    # so all of the properties set on the ErbContext instance are exposed as
    # variables in the binding and therefore the ERB
    # ErbContext is a subclass of OpenStruct
    # TL;DR Magic.
    context = ErbContext.new(@replace)
    context_binding = context.instance_eval { binding }

    yerb = ERB.new(erb)
    return yerb.result(context_binding)
  end
end
