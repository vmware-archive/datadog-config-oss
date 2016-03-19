require "ostruct"

class ErbContext < OpenStruct
  def default_events_json
    <<-JSON
      {
        "q": "tags:deployment:#{environment} start_deploy OR tags:deployment:#{environment} end_deploy"
      }
    JSON
  end

  def threshold_value(widget_query, threshold_color)
    raise 'there are no thresholds defined for this template' if thresholds.nil?
    raise 'default thresholds were not defined' if thresholds == []

    threshold = thresholds.select do |threshold|
      threshold["query"] == widget_query &&
        ( threshold["palette"] == threshold_color || threshold["color"] == threshold_color )
    end.first

    if threshold.nil?
      puts "[WARN] unable to find threshold for:\n query:#{widget_query}, use 0 as default"
      return 0
    end

    threshold["value"]
  end

  def lookup_note_asset(title, screen_or_dash)
    case screen_or_dash
    when :screenboard
      all_things = dog.get_all_screenboards[1]["screenboards"] || []
    when :dashboard
      all_things = dog.get_dashboards[1]["dashes"] || []
    end

    lookup = all_things.find{ |v| v["title"] == title }
    if lookup.nil?
      return ""
    else
      return lookup["id"].to_s
    end
  end
end
