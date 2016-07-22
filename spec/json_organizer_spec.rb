require "spec_helper"

describe "JsonOrganizer" do

  it "sorts hash by keys" do
      expect({"dog"=>1, "cat"=>2}.sort_recursive.to_s).to eq("{\"cat\"=>2, \"dog\"=>1}")
  end

  it "sorts hash by keys recursively" do
    hash = { 'food'=>{"hamburger"=>1, "applepie"=>2}, "animals"=>{"dog"=>3, "cat"=>4} }
    expect(hash.sort_recursive.to_s).to eq(
      "{\"animals\"=>{\"cat\"=>4, \"dog\"=>3}, \"food\"=>{\"applepie\"=>2, \"hamburger\"=>1}}" )
  end

  it "sorts recursively eeven with an array" do
    hash = { 'food'=>[{"hamburger"=>1, "applepie"=>2}], "animals"=>{"dog"=>3, "cat"=>4} }
    expect(hash.sort_recursive.to_s).to eq(
      "{\"animals\"=>{\"cat\"=>4, \"dog\"=>3}, \"food\"=>[{\"applepie\"=>2, \"hamburger\"=>1}]}" )
  end

end
