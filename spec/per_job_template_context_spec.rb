require "spec_helper"

describe PerJobTemplateContext do
  let(:job) { "" }
  let(:template_context) { PerJobTemplateContext.new({foo: "bar"}, job) }

  it "acts like an OpenStruct" do
    expect(template_context.foo).to eq("bar")
  end

  describe "skip_cf" do
    context "when processing a cf job" do
      %w(
        api_z1 api_z2 stats_z1 stats_z2 runner_z1 runner_z2 hm_z1 hm_z1
        login_z1 login_z2 nats_z1 nats_z2 router_z1 router_z2 logs_z1 logs_z2
        uaa_z1 uaa_z2
      ).each do |job|
        context "for job #{job}" do
          let(:job) { job }

          it "skips" do
            expect {
              template_context.skip_cf
            }.to throw_symbol(:skip)
          end
        end
      end
    end

    context "when processing a non-cf job" do
      let(:job) { "hello" }

      it "does not skip it" do
        expect {
          template_context.skip_cf
        }.to_not throw_symbol(:skip)
      end
    end
  end

  describe "skip_services" do
    context "when processing a services job" do
      %w(appdirect_gateway mysql_node_10mb mysql_node_cfinternal
         rds_mysql_gateway uaa).each do |job|
        context "for job #{job}" do
          let(:job) { job }

          it "skips" do
            expect {
              template_context.skip_services
            }.to throw_symbol(:skip)
          end
        end
      end
    end

    context "when processing a non-service job" do
      let(:job) { "hello" }

      it "does not skip it" do
        expect {
          template_context.skip_services
        }.to_not throw_symbol(:skip)
      end
    end
  end
end
