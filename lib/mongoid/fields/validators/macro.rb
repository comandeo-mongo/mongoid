# frozen_string_literal: true
# rubocop:todo all

module Mongoid
  module Fields
    module Validators

      # Validates the params passed to the field macro.
      module Macro
        extend self

        OPTIONS = [
          :as,
          :default,
          :identity,
          :label,
          :localize,
          :fallbacks,
          :association,
          :pre_processed,
          :subtype,
          :type,
          :overwrite,
          :encrypt
        ]

        # Validate the field definition.
        #
        # @example Validate the field definition.
        #   Macro.validate(Model, :name, { localized: true })
        #
        # @param [ Class ] klass The model class.
        # @param [ Symbol ] name The field name.
        # @param [ Hash ] options The provided options.
        def validate(klass, name, options)
          validate_field_name(klass, name)
          validate_name_uniqueness(klass, name, options)
          validate_options(klass, name, options)
          validate_encrypted_association(klass, name, options)
        end

        # Validate the association definition.
        #
        # @example Validate the association definition.
        #   Macro.validate(Model, :name)
        #
        # @param [ Class ] klass The model class.
        # @param [ Symbol ] name The field name.
        # @param [ Hash ] options The provided options.
        def validate_relation(klass, name, options = {})
          [name, "#{name}?".to_sym, "#{name}=".to_sym].each do |n|
            if Mongoid.destructive_fields.include?(n)
              raise Errors::InvalidRelation.new(klass, n)
            end
          end
        end

        # Determine if the field name is valid, if not raise an error.
        #
        # @example Check the field name.
        #   Macro.validate_field_name(Model, :name)
        #
        # @param [ Class ] klass The model class.
        # @param [ Symbol ] name The field name.
        #
        # @raise [ Errors::InvalidField ] If the name is not allowed.
        #
        # @api private
        def validate_field_name(klass, name)
          [name, "#{name}?".to_sym, "#{name}=".to_sym].each do |n|
            if Mongoid.destructive_fields.include?(n)
              raise Errors::InvalidField.new(klass, name, n)
            end
          end
        end

        private

        # Determine if the field name is unique, if not raise an error.
        #
        # @example Check the field name.
        #   Macro.validate_name_uniqueness(Model, :name, {})
        #
        # @param [ Class ] klass The model class.
        # @param [ Symbol ] name The field name.
        # @param [ Hash ] options The provided options.
        #
        # @raise [ Errors::InvalidField ] If the name is not allowed.
        #
        # @api private
        def validate_name_uniqueness(klass, name, options)
          if !options[:overwrite] && klass.fields.keys.include?(name.to_s)
            if Mongoid.duplicate_fields_exception
              raise Errors::InvalidField.new(klass, name, name)
            else
              Mongoid.logger.warn("Overwriting existing field #{name} in class #{klass.name}.") if Mongoid.logger
            end
          end
        end

        # Validate that the field options are allowed.
        #
        # @api private
        #
        # @example Validate the field options.
        #   Macro.validate_options(Model, :name, { localized: true })
        #
        # @param [ Class ] klass The model class.
        # @param [ Symbol ] name The field name.
        # @param [ Hash ] options The provided options.
        #
        # @raise [ Errors::InvalidFieldOption ] If an option is invalid.
        def validate_options(klass, name, options)
          options.keys.each do |option|
            if !OPTIONS.include?(option) && !Fields.options.include?(option)
              raise Errors::InvalidFieldOption.new(klass, name, option, OPTIONS)
            end

            if option == :type && options[option] == Symbol
              Mongoid::Warnings.warn_symbol_type_deprecated
            end
          end
        end

        # Determine if an encrypted field is the foreign key of a
        # has_and_belongs_to_many association. Defining the field after the
        # association has to be rejected, and so does defining it on a parent
        # of the class that declares the association: the field is propagated
        # to the descendants and would replace their association key.
        #
        # @api private
        #
        # @param [ Class ] klass The model class.
        # @param [ Symbol | String ] name The field name.
        # @param [ Hash ] options The provided options.
        #
        # @raise [ Errors::InvalidEncryptedAssociation ] If the field is the
        #   foreign key of a has_and_belongs_to_many association.
        def validate_encrypted_association(klass, name, options)
          return unless options[:encrypt]

          ([ klass ] + klass.descendants).each do |candidate|
            field = candidate.fields[name.to_s]
            next unless field&.foreign_key?

            association = field.association
            next unless association.is_a?(Association::Referenced::HasAndBelongsToMany)

            raise Errors::InvalidEncryptedAssociation.new(candidate, association.name, name)
          end
        end
      end
    end
  end
end
