class MassObject

  # takes a list of attributes.
  # adds attributes to whitelist.
  def self.my_attr_accessible(*attributes)
    @whitelist = attributes.map(&:to_sym)
    self.my_attr_accessor *attributes
  end

  # takes a list of attributes.
  # makes getters and setters
def self.my_attr_accessor(*attributes)
  attributes.each do |attribute|
    define_method(attribute) do
      instance_variable_get("@#{attribute}")
    end

    define_method(attribute.to_s+"=") do |obj|
      instance_variable_set("@#{attribute}",obj)
    end
  end
end


  # returns list of attributes that have been whitelisted.
  def self.attributes
    @whitelist || []
  end

  # takes an array of hashes.
  # returns array of objects.
  def self.parse_all(results)
    results.map { |x| self.new(x) }
  end

  # takes a hash of { attr_name => attr_val }.
  # checks the whitelist.
  # if the key (attr_name) is in the whitelist, the value (attr_val)
  # is assigned to the instance variable.
  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym

      unless self.class.attributes.include? attr_name
        raise "mass assignment to unregistered attribute #{attr_name}"
      end
      instance_variable_set("@#{attr_name}", value)
    end
  end
end
