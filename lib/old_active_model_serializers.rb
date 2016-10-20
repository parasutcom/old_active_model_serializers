require "active_support"
require "active_support/core_ext/string/inflections"
require "active_support/notifications"
require "active_model"
require "active_model/old_array_serializer"
require "active_model/old_serializer"
require "active_model/old_serializer/associations"
require "set"

if defined?(Rails)
  module ActiveModel
    class Railtie < Rails::Railtie
      generators do |app|
        app ||= Rails.application # Rails 3.0.x does not yield `app`

        Rails::Generators.configure!(app.config.generators)
        Rails::Generators.hidden_namespaces.uniq!
        # require_relative "generators/resource_override"
      end

      initializer "include_routes.old_active_model_serializer" do |app|
        ActiveSupport.on_load(:old_active_model_serializers) do
          include app.routes.url_helpers
        end
      end

      initializer "caching.old_active_model_serializer" do |app|
        ActiveModel::OldSerializer.perform_caching = app.config.action_controller.perform_caching
        ActiveModel::OldArraySerializer.perform_caching = app.config.action_controller.perform_caching

        ActiveModel::OldSerializer.cache = Rails.cache
        ActiveModel::OldArraySerializer.cache = Rails.cache
      end
    end
  end
end

module ActiveModel::OldSerializerSupport
  extend ActiveSupport::Concern

  module ClassMethods #:nodoc:
    if "".respond_to?(:safe_constantize)
      def old_active_model_serializer
        "#{self.name}Serializer".safe_constantize
      end
    else
      def old_active_model_serializer
        begin
          "#{self.name}Serializer".constantize
        rescue NameError => e
          raise unless e.message =~ /uninitialized constant/
        end
      end
    end
  end

  # Returns a model serializer for this object considering its namespace.
  def old_active_model_serializer
    self.class.old_active_model_serializer
  end

  alias :read_attribute_for_serialization :send
end

module ActiveModel::OldArraySerializerSupport
  def old_active_model_serializer
    ActiveModel::OldArraySerializer
  end
end

Array.send(:include, ActiveModel::OldArraySerializerSupport)
Set.send(:include, ActiveModel::OldArraySerializerSupport)

{
  :active_record => 'ActiveRecord::Relation',
  :mongoid => 'Mongoid::Criteria'
}.each do |orm, rel_class|
  ActiveSupport.on_load(orm) do
    include ActiveModel::OldSerializerSupport
    rel_class.constantize.send(:include, ActiveModel::OldArraySerializerSupport)
  end
end

begin
  require 'action_controller'
  require 'action_controller/old_serialization'

  # ActiveSupport.on_load(:action_controller) do
  #   include ::ActionController::OldSerialization
  # end
rescue LoadError => ex
  # rails on installed, continuing
end

ActiveSupport.run_load_hooks(:old_active_model_serializers, ActiveModel::OldSerializer)
