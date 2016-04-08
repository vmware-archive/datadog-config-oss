require 'json'

class Hash
  def sort_recursive(&block)
    self.keys.sort(&block).reduce({}) do |seed, key|
      seed[key] = self[key]
      if seed[key].is_a?(Hash)
        seed[key] = seed[key].sort_recursive(&block)
      elsif seed[key].is_a?(Array)
        seed[key].each do |item|
          if item.is_a?(Hash)
            item = item.sort_recursive
          end
        end
        seed[key].sort! { |x,y| x.to_s <=> y.to_s }
      end
      seed
    end
  end
end

def sort_json(json)
  jsonHash = JSON.parse(json)
  return JSON.generate(jsonHash.sort_recursive)
end
