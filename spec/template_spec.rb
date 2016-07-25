require 'rspec'

describe Template do
  subject(:template) {described_class.new()}

  it { is_expected.to be_a Template }

end
