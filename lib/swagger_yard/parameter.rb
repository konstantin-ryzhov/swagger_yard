module SwaggerYard
  class Parameter
    attr_accessor :name, :description
    attr_reader :param_type, :required, :allow_multiple, :allowable_values

    def self.from_yard_tag(tag, operation)
      description = tag.text
      name, options_string = tag.name.split(/[\(\)]/)
      type = Type.from_type_list(tag.types)

      options = {}

      operation.model_names << type.name if type.ref?

      unless options_string.nil?
        options_string.split(',').map(&:strip).tap do |arr|
          options[:required] = !arr.delete('required').nil?
          options[:allow_multiple] = !arr.delete('multiple').nil?
          options[:param_type] = arr.last
        end
      end

      new(name, type, description, options)
    end

    # TODO: support more variation in scope types
    def self.from_path_param(name)
      new(name, Type.new("string"), "Scope response to #{name}", {
        required: true,
        allow_multiple: false,
        param_type: "path"
      })
    end

    def initialize(name, type, description, options={})
      @name, @type, @description = name, type, description

      @required = options[:required] || false
      @param_type = options[:param_type] || 'query'
      @allow_multiple = options[:allow_multiple] || false
      @allowable_values = options[:allowable_values] || []
    end

    def type
      @type.name
    end

    def allowable_values_hash
      return nil if allowable_values.empty?

      {
        "valueType" => "LIST",
        "values" => allowable_values
      }
    end

    def to_h
      {
        "paramType"       => param_type,
        "name"            => name,
        "description"     => description,
        "required"        => required,
        "allowMultiple"   => !!allow_multiple,
        "allowableValues" => allowable_values_hash 
      }.merge(@type.to_h).reject {|k,v| v.nil?}
    end

    def swagger_v2
      { name:        name,
        description: description,
        required:    required,
        in:          param_type
      }.with_indifferent_access.tap do |h|
        if allowable_values.present?
          h[:enum] = allowable_values
        end
        if h[:in] == "body"
          h[:schema] = @type.swagger_v2
        else
          h.update(@type.swagger_v2)
        end
        h[:collectionFormat] = 'multi' if allow_multiple.present? && h[:items]
      end
    end
  end
end
