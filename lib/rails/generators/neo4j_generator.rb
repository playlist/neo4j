require 'rails/generators/named_base'
require 'rails/generators/active_model'

module Neo4j
  module Generators #:nodoc:
  end
end

module Neo4j::Generators::MigrationHelper
  extend ActiveSupport::Concern

  def migration_file_name(file_name)
    "#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_#{file_name.parameterize}.rb"
  end

  def migration_template(template_name)
    real_file_name = migration_file_name(file_name)
    @migration_class_name = file_name.camelize

    template template_name, File.join('db/neo4j/migrate', real_file_name)
  end
end

module Neo4j::Generators::SourcePathHelper
  extend ActiveSupport::Concern

  module ClassMethods
    def source_root
      @_neo4j_source_root ||= File.expand_path(File.join(File.dirname(__FILE__),
                                                         'neo4j', generator_name, 'templates'))
    end
  end
end


class Neo4j::Generators::ActiveModel < Rails::Generators::ActiveModel #:nodoc:
  def self.all(klass)
    "#{klass}.all"
  end

  def self.find(klass, params = nil)
    "#{klass}.find(#{params})"
  end

  def self.build(klass, params = nil)
    if params
      "#{klass}.new(#{params})"
    else
      "#{klass}.new"
    end
  end

  def save
    "#{name}.save"
  end

  def update_attributes(params = nil)
    "#{name}.update_attributes(#{params})"
  end

  def errors
    "#{name}.errors"
  end

  def destroy
    "#{name}.destroy"
  end
end


module Rails
  module Generators
    class GeneratedAttribute #:nodoc:
      def type_class
        case type.to_s.downcase
        when 'any' then 'any'
        when 'datetime' then 'DateTime'
        when 'date' then 'Date'
        when 'integer', 'number', 'fixnum' then 'Integer'
        when 'float' then 'Float'
        else
          'String'
        end
      end
    end
  end
end
