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
        on: :create,
        update_on_source_change: true,
        force_unique_naming: false,
        max_length: 60,
        character_substitutions: {
          ampersand:  false,
          slash:      false,
          dot:        false
        }
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
        # force error validation if existing object is found
        # rather than adding numbers to permalink to save and bypass validation
        set_var('@force_unique_naming', options[:force_unique_naming])
        # maximum length of the permalink
        set_var('@permalink_length', options[:max_length])
        # options for character substitutions before scrubbing
        set_var('@character_substitutions', options[:character_substitutions])
      end

      def apply_validations(options)
        before_validation :update_permalink, on: options[:on]

        uniqueness_options = { scope: options[:scope] }

        # checks if acts_as_paranoid is being used
        if table_exists? && column_names.include?("deleted_at")
          uniqueness_options.merge!(
            conditions: -> { where('deleted_at is null') }
          )
        end

        validates_uniqueness_of @permalink_column_name, uniqueness_options
      end

      def set_var(key, value)
        self.base_class.instance_variable_set(key, value)
      end

      def find_all_by_permalink_from_text(text)
        obj = self.new
        obj.send("#{instance_variable_get('@permalink_source')}=", text)

        # contruct sql for where query so that we can find
        # *all* possible records with this permalink
        # e.g. "WHERE (sellect_option_values.permalink = 'blah')"
        where_sql = "#{self.table_name}.#{instance_variable_get('@permalink_column_name')} = ?"
        self.where(where_sql, obj.generate_permalink)
      end

      def find_by_permalink_from_text(text)
        find_all_by_permalink_from_text(text).first
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
          # substitute characters before further scrubbing
          text = apply_character_substitutions(text)
          # make any character that is not numeric or alphabetic into a dash
          text = text.gsub(/[^a-z0-9\w]/, "-")
          # remove dashes on either end, caused by non-simplified characters
          text = text.sub(/-+$/, "").sub(/^-+/, "")
          # remove multiple dashes in a row
          text = text.gsub(/-+/,"-")
          # trim to length
          text = text[0...get_var('@permalink_length')]
        end
        text
      end

      def apply_character_substitutions(text)
        sub_options = get_var('@character_substitutions')

        text = text.gsub(/\&+/, "-and-")     if sub_options[:ampersand]
        text = text.gsub(/\/+/, "-slash-")   if sub_options[:slash]
        text = text.gsub(/\.+/, "-dot-")     if sub_options[:dot]
      end

      def ensure_uniqueness(text)
        # if we're forcing unique naming, we don't want numbered permalinks
        # so we don't care if the object exists, we will just let the
        # permalink validate as is (throwing validation error, if necessary)
        return text if get_var('@force_unique_naming')

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
