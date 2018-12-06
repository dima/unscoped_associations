require 'unscoped_associations/version'

class Module
  def fallback_alias_method_chain(target, feature)
    # Strip out punctuation on predicates, bang or writer methods since
    # e.g. target?_without_feature is not a valid method name.
    aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
    yield(aliased_target, punctuation) if block_given?

    with_method = "#{aliased_target}_with_#{feature}#{punctuation}"
    without_method = "#{aliased_target}_without_#{feature}#{punctuation}"

    alias_method without_method, target
    alias_method target, with_method

    case
    when public_method_defined?(without_method)
      public target
    when protected_method_defined?(without_method)
      protected target
    when private_method_defined?(without_method)
      private target
    end
  end
end

module UnscopedAssociations
  def self.included(base)
    base.extend ClassMethods
    class << base
      self.class_eval do
        fallback_alias_method_chain :belongs_to, :unscoped

        fallback_alias_method_chain :has_many, :unscoped

        fallback_alias_method_chain :has_one, :unscoped
      end
    end
  end

  module ClassMethods
    def belongs_to_with_unscoped(name, scope = nil, options = {})
      build_unscoped(:belongs_to, name, scope, options)
    end

    def has_many_with_unscoped(name, scope = nil, options = {}, &extension)
      build_unscoped(:has_many, name, scope, options, &extension)
    end

    def has_one_with_unscoped(name, scope = nil, options = {})
      build_unscoped(:has_one, name, scope, options)
    end


    private

    def build_unscoped(assoc_type, assoc_name, scope = nil, options = {}, &extension)
      if scope.is_a?(Hash)
        options = scope
        scope   = nil
      end

      if options.delete(:unscoped)
        add_unscoped_association(assoc_name)
      end

      if scope
        send("#{assoc_type}_without_unscoped", assoc_name, scope, options, &extension)
      else
        send("#{assoc_type}_without_unscoped", assoc_name, options, &extension)
      end
    end

    def add_unscoped_association(association_name)
      define_method(association_name) do |*args|
        force_reload = args[0]
        if !force_reload && instance_variable_get("@_cache_#{association_name}")
          instance_variable_get("@_cache_#{association_name}")
        else
          instance_variable_set("@_cache_#{association_name}",
            association(association_name).klass.unscoped { super(true) }
          )
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, UnscopedAssociations)