require 'date'

module Neo4j::Shared
  module TypeConverters
    # Converts Date objects to Java long types. Must be timezone UTC.
    class DateConverter
      class << self
        def convert_type
          Date
        end

        def db_type
          Integer
        end

        def to_db(value)
          Time.utc(value.year, value.month, value.day).to_i
        end

        def to_ruby(value)
          Time.at(value).utc.to_date
        end
      end
    end

    # Converts DateTime objects to and from Java long types. Must be timezone UTC.
    class DateTimeConverter
      class << self
        def convert_type
          DateTime
        end

        def db_type
          Integer
        end

        # Converts the given DateTime (UTC) value to an Integer.
        # DateTime values are automatically converted to UTC.
        def to_db(value)
          value = value.new_offset(0) if value.respond_to?(:new_offset)

          args = [value.year, value.month, value.day]
          args += (value.class == Date ? [0, 0, 0] : [value.hour, value.min, value.sec])

          Time.utc(*args).to_i
        end

        DATETIME_FORMAT = '%Y-%m-%d %H:%M:%S %z'
        def to_ruby(value)
          t = case value
              when Integer
                Time.at(value).utc
              when String
                DateTime.strptime(value, DATETIME_FORMAT)
              else
                fail ArgumentError, "Invalid value type for DateType property: #{value.inspect}"
              end

          DateTime.civil(t.year, t.month, t.day, t.hour, t.min, t.sec)
        end
      end
    end

    class TimeConverter
      class << self
        def convert_type
          Time
        end

        # ActiveAttr, which assists with property management, does not recognize Time as a valid type. We tell it to interpret it as
        # Integer, as it will be when saved to the database.
        def primitive_type
          Integer
        end

        def db_type
          Integer
        end

        # Converts the given DateTime (UTC) value to an Integer.
        # Only utc times are supported !
        def to_db(value)
          if value.class == Date || value.class == DateTime
            Time.utc(value.year, value.month, value.day, 0, 0, 0).to_i * 1000
          else
            (value.utc.to_i * 1000) + (value.utc.usec / 1000)
          end
        end

        def to_ruby(value)
          if value.class == Date || value.class == DateTime || value.class == Time
            Time.at(value).utc
          else
            Time.at(value / 1000, (value % 1000) * 1000).utc
          end
        end
        alias_method :call, :to_ruby
      end
    end

    # Converts hash to/from YAML
    class YAMLConverter
      class << self
        def convert_type
          Hash
        end

        def db_type
          String
        end

        def to_db(value)
          Psych.dump(value)
        end

        def to_ruby(value)
          Psych.load(value)
        end
      end
    end

    # Converts hash to/from JSON
    class JSONConverter
      class << self
        def convert_type
          JSON
        end

        def db_type
          String
        end

        def to_db(value)
          value.to_json
        end

        def to_ruby(value)
          JSON.parse(value, quirks_mode: true)
        end
      end
    end

    # Modifies a hash's values to be of types acceptable to Neo4j or matching what the user defined using `type` in property definitions.
    # @param [Neo4j::Shared::Property] obj A node or rel that mixes in the Property module
    # @param [Symbol] medium Indicates the type of conversion to perform.
    # @param [Hash] properties A hash of symbol-keyed properties for conversion.
    def convert_properties_to(obj, medium, properties)
      direction = medium == :ruby ? :to_ruby : :to_db
      properties.each_pair do |key, value|
        next if skip_conversion?(obj, key, value)
        properties[key] = convert_property(key, value, direction)
      end
    end

    # Converts a single property from its current format to its db- or Ruby-expected output type.
    # @param [Symbol] key A property declared on the model
    # @param value The value intended for conversion
    # @param [Symbol] direction Either :to_ruby or :to_db, indicates the type of conversion to perform
    def convert_property(key, value, direction)
      converted_property(primitive_type(key.to_sym), value, direction)
    end

    private

    def converted_property(type, value, converter)
      TypeConverters.converters[type].nil? ? value : TypeConverters.to_other(converter, value, type)
    end

    # If the attribute is to be typecast using a custom converter, which converter should it use? If no, returns the type to find a native serializer.
    def primitive_type(attr)
      case
      when self.serialized_properties_keys.include?(attr)
        serialized_properties[attr]
      when self.magic_typecast_properties_keys.include?(attr)
        self.magic_typecast_properties[attr]
      else
        self.fetch_upstream_primitive(attr)
      end
    end

    # Returns true if the property isn't defined in the model or if it is nil
    def skip_conversion?(obj, attr, value)
      !obj.class.attributes[attr] || value.nil?
    end

    class << self
      attr_reader :converters

      def included(_)
        return if @converters
        @converters = {}
        Neo4j::Shared::TypeConverters.constants.each do |constant_name|
          constant = Neo4j::Shared::TypeConverters.const_get(constant_name)
          register_converter(constant) if constant.respond_to?(:convert_type)
        end
      end

      def typecaster_for(primitive_type)
        return nil if primitive_type.nil?
        converters.key?(primitive_type) ? converters[primitive_type] : nil
      end

      # @param [Symbol] direction either :to_ruby or :to_other
      def to_other(direction, value, type)
        fail "Unknown direction given: #{direction}" unless direction == :to_ruby || direction == :to_db
        found_converter = converters[type]
        return value unless found_converter
        return value if direction == :to_db && formatted_for_db?(found_converter, value)
        found_converter.send(direction, value)
      end

      # Attempts to determine whether conversion should be skipped because the object is already of the anticipated output type.
      # @param [#convert_type] found_converter An object that responds to #convert_type, hinting that it is a type converter.
      # @param value The value for conversion.
      def formatted_for_db?(found_converter, value)
        found_converter.respond_to?(:db_type) && value.is_a?(found_converter.db_type)
      end

      def register_converter(converter)
        converters[converter.convert_type] = converter
      end
    end
  end
end
