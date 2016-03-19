require "synchronizer"

class AlertSynchronizer < Synchronizer
  def key_of(alert)
    alert.fetch(:name)
  end

  def update(id, alert)
    key = key_of(alert)
    logger.info "Updating alert #{key}"

    # we don't want the query in the hash, they are separate parameters to datadog
    query = alert.delete(:query)

    result = @dog.update_alert(id, query, alert)

    if result.first != '200'
      logger.error "Failed to update alert #{key.inspect}(#{result.first}): #{result.last}"
    end
  end

  def create(alert)
    key = key_of(alert)
    logger.info "Creating alert #{key}"

    # we don't want the query in the hash, they are separate parameters to datadog
    query = alert.delete(:query)

    result = @dog.alert(query, alert)

    if !['200', '201'].include?(result.first)
      logger.error "Failed to create alert #{key.inspect}(#{result.first}): #{result.last}"
    end
  end

  # @return [Hash] alert name -> alert id
  def fetch_from_datadog
    dog_alerts = handle_datadog_errors { @dog.get_all_alerts }
    alerts = dog_alerts.fetch('alerts', [])
    logger.info "Found #{alerts.size} alerts at Datadog"

    result = {}
    alerts.each do |alert|
      result[alert['name']] = alert['id']
    end

    result
  end

  def unknown_alert_names(templates)
    unknown_datadog_object_names(known_object_names(templates))
  end

  def unknown_alert_ids(templates)
    unknown_datadog_object_ids(known_object_names(templates))
  end

  def delete_unknown_alerts(templates)
    unknown_alert_ids(templates).each do |alert_id|
      @dog.delete_alert(alert_id)
    end
  end

  def delete(id)
    @dog.delete_alert(id)
  end


  def fetch_by_id(id)
    @dog.get_alert(id)
  end

  private

  def known_object_names(templates)
    local_object_names(templates)
  end


end
