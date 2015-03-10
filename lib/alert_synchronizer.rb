require "synchronizer"
require "per_job_template_context"

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
    alerts = dog_alerts.fetch('alerts')
    logger.info "Found #{alerts.size} alerts at Datadog"

    result = {}
    alerts.each do |alert|
      result[alert['name']] = alert['id']
    end

    result
  end

  def unknown_alert_names(templates, per_job_templates)
    unknown_datadog_object_names(known_object_names(per_job_templates, templates))
  end

  def unknown_alert_ids(templates, per_job_templates)
    unknown_datadog_object_ids(known_object_names(per_job_templates, templates))
  end

  def delete_unknown_alerts(templates, per_job_templates)
    unknown_alert_ids(templates, per_job_templates).each do |alert_id|
      @dog.delete_alert(alert_id)
    end
  end

  def run_per_job(templates)
    found = fetch_from_datadog

    @env["jobs"].each do |job|
      templates.each do |template_path|
        catch(:skip) do
          alert = symbolize_keys(process_job_template(job, template_path))
          id = found[key_of(alert)]

          if id
            update(id, alert)
          else
            create(alert)
          end
        end
      end
    end
  end

  def fetch_by_id(id)
    @dog.get_alert(id)
  end

  private

  def known_object_names(per_job_templates, templates)
    known_object_names = local_object_names(templates)

    @env["jobs"].each do |job|
      per_job_templates.each do |template_path|
        catch(:skip) do
          known_object_names << key_of(symbolize_keys(process_job_template(job, template_path)))
        end
      end
    end
    known_object_names
  end

  def process_job_template(current_job, template_path)
    context = PerJobTemplateContext.new(@env, current_job)
    template = File.new(template_path).read
    json = ERB.new(template).result(context.template_binding)
    JSON.parse(json)
  end
end
