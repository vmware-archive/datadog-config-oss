require "synchronizer"

class ScreenSynchronizer < Synchronizer

  def fetch_from_datadog
    dog_response = handle_datadog_errors { @dog.get_all_screenboards }
    screens = dog_response.fetch('screenboards', [])
    logger.info "Found #{screens.size} screenboards at Datadog"

    screens.each_with_object({}) do |screen, screens|
      screens[screen['title']] = screen['id']
    end
  end

  def key_of(screen)
    screen[:board_title]
  end

  def update(id, screen)
    result = @dog.update_screenboard(id, screen)
    if result[0] != "200"
      logger.error "Failed to update screen #{result.inspect}"
    end
  end

  def create(screen)
    result = @dog.create_screenboard(screen)
    if result[0] != "200"
      logger.error "Failed to create screen #{result.inspect}"
    end
  end

  def delete(id)
    @dog.delete_screenboard(id)
  end

  def unknown_screen_names(templates)
    unknown_datadog_object_names(local_object_names(templates))
  end

  def unknown_screen_ids(templates)
    unknown_datadog_object_ids(local_object_names(templates))
  end

  def delete_unknown_screens(templates)
    unknown_screen_ids(templates).each do |dashboard_id|
      @dog.delete_screenboard(dashboard_id)
    end
  end

  def convert_json_to_template(template_output_file, screen)
    yaml_array = []
    yaml_hash = {
      @environment => yaml_array
    }
    screen["widgets"].each do |widget|
      widget.delete("board_id")
      conditionals = widget["conditional_formats"]
      next unless conditionals


      # replace <%= key %> to key to avoid nested <%= %> issue
      widget_identifier = derender(widget["query"], {erb_token: false}).strip
      conditionals.each do |conditional|
        palette = conditional["palette"]
        value = conditional["value"]
        conditional["value"] = "<%= threshold_value('#{widget_identifier}', '#{palette}') %>"
        yaml_array << {"query" => widget_identifier, "palette" => palette, "value" => value}
      end
    end

    yaml_file_name = File.join(
      File.dirname(template_output_file),
      File.basename(template_output_file).split('.').first + '_thresholds.yml'
    )
    File.open(yaml_file_name, 'w') { |file| file.write(yaml_hash.to_yaml(line_width: -1)) }

    logger.info  "current threshold values written to #{yaml_file_name}, put sibling with template to use"

    generalize_note_link_for_template(screen)
    str = JSON.pretty_generate(screen).
      gsub('"<%=', '<%=').
        gsub('%>"', '%>')
    str = derender(str)
    str.gsub(/#{@env.fetch('environment')}(?!uction|-)/, "<%= environment %>")
  end

  def fetch_by_id(id)
    @dog.get_screenboard(id)
  end

  def filter_environment_specifics(title)
    text = title.gsub(@env.fetch('bosh_deployment'), " bosh_deployment + \'")
    text.gsub!(@env.fetch('deployment'), " deployment + \'")
    text.gsub!(/#{@env.fetch('environment')}(?!uction|-)/, "environment + \'")
    text
  end


  def identify_target_link(url)
    case url
    when /\/dash/
      id = url.match(/.*\/dash\/(\d+).*/).captures.first
      title = @dog.get_dashboards[1]["dashes"].select { |v| v["id"] == id }.first["title"]
      if title == filter_environment_specifics(title)
        return "/dash/dash/<%= lookup_note_asset('#{title}', :dashboard) %>"
      else
        return "/dash/dash/<%= lookup_note_asset(#{filter_environment_specifics(title)}\', :dashboard) %>"
      end
    when /\/screen/
      id = url.match(/.*\/screen\/(\w+\/)*(\d+).*/).captures.last
      title = @dog.get_all_screenboards[1]["screenboards"].select { |v| v["id"] == id.to_i }.first["title"]
      if title == filter_environment_specifics(title)
        return "/screen/board/<%= lookup_note_asset('#{title}', :screenboard) %>"
      else
        return "/screen/board/<%= lookup_note_asset(#{filter_environment_specifics(title)}\', :screenboard) %>"
      end
    else
      url
    end

  end

  protected

  def generalize_note_link_for_template(screen)
    note_widgets = screen["widgets"].select { |v|
      v["type"] == 'note'
    }

    note_widgets.map do |v|
      if match = v["html"].match(/.*\[.*\]\((\/.*)\).*/)
        key = match[1]
        v["html"][key] = identify_target_link(key)
      end
    end

    screen

  end

end
