class PerJobTemplateContext < OpenStruct
  CF_JOBS = %w(api runner router stats logs hm uaa login nats).collect do |name|
    ["#{name}_z1", "#{name}_z2"]
  end.flatten.collect(&:freeze).freeze

  SERVICES_JOBS = %w(appdirect_gateway mysql_node_10mb mysql_node_cfinternal
         rds_mysql_gateway uaa).freeze

  def initialize(env, job)
    super(env)
    self.job = job
  end

  def template_binding
    binding
  end

  def skip_cf
    throw :skip if CF_JOBS.include? job
  end

  def skip_services
    throw :skip if SERVICES_JOBS.include? job
  end
end
