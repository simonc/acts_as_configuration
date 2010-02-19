def debug(msg)
  RAILS_DEFAULT_LOGGER.debug(msg)
end

module ActiveRecord
  module Acts
    module Configuration

      # ========================================================================
      # =                                                             INCLUDED =
      # ========================================================================
      def self.included(base)
        base.extend ClassMethods
      end

      # ========================================================================
      # =                                                              ACTS AS =
      # ========================================================================
      module ClassMethods
        def acts_as_configuration(options={})
          conf = {
            :system_column => 'system',
            :data_column   => 'data',
            :system_value  => true
          }

          conf.update(options) if options.is_a?(Hash)

          class_eval %Q{
            attr_accessor :all_data

            before_save :data_to_yaml

            @locked_fields_list   = []
            @unlocked_fields_list = []

            def self.system
              find_or_create_by_#{conf[:system_column]}('#{conf[:system_value]}')
            end
          }

          define_method 'system?' do
            send(conf[:system_column]) == conf[:system_value]
          end

          define_method 'data' do
            send(conf[:data_column])
          end

          define_method 'data=' do |value|
            send("#{conf[:data_column]}=", value)
          end

          include ActiveRecord::Acts::Configuration::InstanceMethods
        end

        def config_fields(fields={})
          # FIXME: Warn when a field is not created
          fields.each_pair do |field, infos|
            unless self.respond_to?(field, true)
              define_method field do
                self.all_data[field]
              end

              define_method "#{field}=" do |value|
                self.all_data[field] = value
              end
            end
          end
        end

        def locked_fields(*locked)
          @locked_fields_list |= locked
        end

        def locked_fields_list
          @unlocked_fields_list
        end

        def unlocked_fields(*unlocked)
          @unlocked_fields_list |= unlocked
        end

        def unlocked_fields_list
          @unlocked_fields_list
        end
      end

      # ========================================================================
      # =                                                     INSTANCE METHODS =
      # ========================================================================

      module InstanceMethods
        # ======================================================================
        # =                                                     PUBLIC METHODS =
        # ======================================================================

        def update_data(new_data={})
          # FIXME: filter using config_fields and rules
          self.all_data = new_data
        end
        
        # ======================================================================
        # =                                                   INTERNAL METHODS =
        # ======================================================================
        
        # before_validation
        def filter_entries
          unless system?
            system_data = self.class.system.all_data
            self.all_data.delete_if! { |k, v| system_data[k] == v }
          end
        end
        
        # before_save
        def data_to_yaml
          self.data = self.all_data.to_yaml
        end

        def after_find
          self.all_data = {}
          own_data = YAML.load(data)
          unless system?
            system_data = self.class.system.data
            own_data = system_data.update(own_data)
          end
          self.all_data = own_data if own_data.is_a?(Hash)
        end
      end

    end
  end
end
