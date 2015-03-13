# ActsAsPermalink
module Acts #:nodoc:
  module Permalink #:nodoc:

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      DEFAULT_OPTIONS = {
        to: :permalink,
        from: :title,
        update_on_source_change: true,
        max_length: 60,
        on: :create
      }

      def acts_as_permalink(options={})
        options = DEFAULT_OPTIONS.merge(options)
        set_instance_variables(options)
        apply_validations(options)
        
        include Acts::Permalink::InstanceMethods
      end

      def set_instance_variables(options)
        # column which will save the permalink
        set_var('@permalink_column_name', options[:to])
        # column or function which will generate the permalink
        set_var('@permalink_source', options[:from])
        # should permalink be updated when @permalink_source changes
        set_var('@update_on_source_change', options[:update_on_source_change])
        # maximum length of the permalink
        set_var('@permalink_length', options[:max_length])
      end

      def apply_validations(options)
        before_validation :update_permalink, on: options[:on]
        if respond_to?(:deleted_at)
          validates_uniqueness_of @permalink_column_name, scope: Array(options[:scope]).unshift(:deleted_at)
        else
          validates_uniqueness_of @permalink_column_name, scope: options[:scope]
        end
      end

      def set_var(key, value)
        self.base_class.instance_variable_set(key, value)
      end

    end
    
    module InstanceMethods

      # Generate the permalink and assign it directly via callback
      def update_permalink
        updated_permalink = generate_permalink
        return true if updated_permalink == self.permalink

        self.send("#{get_var('@permalink_column_name')}=", updated_permalink)
        true
      end

      # Returns the unique permalink string for the passed in object.
      def generate_permalink
        text = initial_permalink_text
        text = scrub_text(text)
        text = ensure_uniqueness(text)
        text
      end

      def initial_permalink_text
        if new_record? || get_var('@update_on_source_change')
          send get_var('@permalink_source')
        else
          send get_var('@permalink_column_name')
        end
      end

      def scrub_text(text)
        if text.blank?
          # if blank then generate a random link
          text = random_permalink
        else
          # make the string lowercase and scrub white space on either side
          text = text.downcase.strip
          # make any character that is not nupermic or alphabetic into a dash
          text = text.gsub(/[^a-z0-9\w]/, "-")
          # remove dashes on either end, caused by non-simplified characters
          text = text.sub(/-+$/, "").sub(/^-+/, "")
          # trim to length
          text = text[0...get_var('@permalink_length')]
        end
        text
      end

      def ensure_uniqueness(text)
        found_object = find_by_permalink_column_name(text)
        if found_object && found_object != self
          # If we find the object we know there is a collision
          # so just add a number to the end until there is no collision
          num  = 1
          num += 1 while find_by_permalink_column_name(text + num.to_s)
          text = text + num.to_s
        end
        text
      end

      def random_permalink
        self.class.base_class.to_s.downcase + rand(10000).to_s
      end

      def get_var(key)
        self.class.base_class.instance_variable_get(key)
      end

      def find_by_permalink_column_name(text)
        column_name = get_var('@permalink_column_name')
        self.class.base_class.send("find_by_#{column_name}", text)
      end

    end
  end
end

ActiveRecord::Base.send(:include, Acts::Permalink)
