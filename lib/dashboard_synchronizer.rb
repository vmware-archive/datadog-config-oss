require "synchronizer"

class DashboardSynchronizer < Synchronizer

  # @return [Hash] dashboard title -> dashboard id
  def fetch_from_datadog
    dog_response = handle_datadog_errors { @dog.get_dashboards }
    dashes = dog_response.fetch('dashes', [])
    logger.info "Found #{dashes.size} dashboards at Datadog"

    result = {}
    dashes.each do |dash|
      result[dash['title']] = dash['id']
    end

    result
  end

  def key_of(dashboard)
    dashboard[:title]
  end

  def update(id, dashboard)
    key = key_of(dashboard)
    logger.info "Updating dashboard #{key}"

    title = dashboard.fetch(:title) { logger.error("Missing :title") }
    description = dashboard.fetch(:description) { logger.error("Missing :description") }
    graphs = dashboard.fetch(:graphs) { logger.error("Missing :graphs") }
    template_variables = dashboard[:template_variables]

    result = @dog.update_dashboard(id, title, description, graphs, template_variables)

    if result.first != '200'
      logger.error "Failed to update dashboard #{key.inspect}(#{result.first}): #{result.last}"
    end
  rescue => e
    logger.error(e)
    raise e
  end

  def create(dashboard)
    key = key_of(dashboard)
    logger.info "Creating dashboard #{key}"

    title = dashboard.fetch(:title)
    description = dashboard.fetch(:description)
    graphs = dashboard.fetch(:graphs)
    template_variables = dashboard.fetch(:template_variables, nil)

    result = @dog.create_dashboard(title, description, graphs, template_variables)

    if result.first != '200'
      logger.error "Failed to create dashboard #{key.inspect}(#{result.first}): #{result.last}"
    end
  rescue => e
    logger.error(e)
    raise e
  end

  def delete(id)
    @dog.delete_dashboard(id)
  end

  def unknown_dashboard_names(templates)
    unknown_datadog_object_names(local_object_names(templates))
  end

  def unknown_dashboard_ids(templates)
    unknown_datadog_object_ids(local_object_names(templates))
  end

  def delete_unknown_dashboards(templates)
    unknown_dashboard_ids(templates).each do |dashboard_id|
      @dog.delete_dashboard(dashboard_id)
    end
  end

  def fetch_by_id(id)
    code, board = @dog.get_dashboard(id)
    [code, board && board['dash']]
  end
end
