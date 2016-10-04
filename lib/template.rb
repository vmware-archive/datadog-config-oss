require "erb"
require "erb_context"
require 'active_support/core_ext/hash/indifferent_access'

class Template
  def initialize(params)
    build_search_and_replace(params.fetch(:search_and_replace))
    @erb_value = params.fetch(:erb, nil)
    add_alert_header(params)
    @string_value = params.fetch(:string, nil)
    @additional_value = params.fetch(:additional, nil)
  end

  def add_alert_header(params)
    # only alerts have message field
    # this inserts the header, which looks like:
    #   <%= params.fetch("alert_header", "") %>\n\n
    return if @erb_value.nil? || @erb_value =~ /alert_header/
    @erb_value.sub!('"message": "', '"message": "<%= params.fetch("alert_header", false)  && params ? params.fetch("alert_header") + "\n\n" : "" %>')
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
    raise "Problem parsing search_and_replace!" unless shwing
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

  def to_generic
    shtring = string.dup
    @search.each do |k,v|
      shtring.gsub!(v, "#{k}" )
    end
    shtring
  end

  def to_generic_ruby
    shtring = string.dup
    @search.each do |k,v|
      stuff =  inflate_regex(v).match(shtring)
      next unless stuff
      shtring = %Q|#{"'" + stuff[1] + "' + " if (stuff[1] && ! stuff[1].empty?)}#{k}#{" + '"  + stuff[-1] + "'" if (stuff[-1] && ! stuff[-1].empty?)}|
    end
    shtring
  end

  def inflate_regex(regex)
    Regexp.new( '(.*)' + regex.inspect.reverse.chomp('/').reverse.chomp('/') + '(.*)')
  end

  def string
    @string_value ||= to_string
  end

  def additional
    @additional_value || {}
  end

  def context
    @replace.merge(additional)
  end

  def to_string
    # this returns the binding as it exists from the context's perspective
    # so all of the properties set on the ErbContext instance are exposed as
    # variables in the binding and therefore the ERB
    # ErbContext is a subclass of OpenStruct
    # TL;DR Magic.
    erb_context = ErbContext.new(context)
    erb_context_binding = erb_context.instance_eval { binding }

    yerb = ERB.new(erb)
    return yerb.result(erb_context_binding)
  end

end
