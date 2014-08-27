# ActsAsPermalink
module Acts #:nodoc:
  module Permalink #:nodoc:

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def acts_as_permalink(options={})
        # Read and scrub option for the column which will save the permalink    
        self.base_class.instance_variable_set('@permalink_column_name', options[:to].try(:to_sym) || :permalink)

        # Read and scrub the option for the column or function which will generate the permalink 
        self.base_class.instance_variable_set('@permalink_source', (options[:from].try(:to_sym) || :title))

        # Read and scrub the option for whether the permalink should be updated when @permalink_source chnages
        update_on_source_change = options[:update_on_source_change].nil? ? true : options[:update_on_source_change]
        self.base_class.instance_variable_set('@update_on_source_change', update_on_source_change )

        # Read and validate the maximum length of the permalink
        max_length = options[:max_length].to_i rescue 0
        max_length = 60 unless max_length && max_length > 0
        self.base_class.instance_variable_set('@permalink_length', max_length)

        before_validation :update_permalink #, on: [:create, :save]

        validates_uniqueness_of @permalink_column_name
        
        include Acts::Permalink::InstanceMethods
        extend Acts::Permalink::SingletonMethods
      end
      
      def update_permalink_on_name_change?(obj)
        obj.class.base_class.instance_variable_get('@update_on_source_change')
      end

      def initial_permalink_text(obj)
        if obj.new_record? || update_permalink_on_name_change?(obj)
          obj.send(obj.class.base_class.instance_variable_get('@permalink_source'))
        else
          obj.send(obj.class.base_class.instance_variable_get('@permalink_column_name'))
        end
      end

      def scrub_text(obj, text)
        # If it is blank then generate a random link
        if text.blank?
          text = obj.class.base_class.to_s.downcase + rand(10000).to_s

        # If it is not blank, scrub
        else
          text = text.downcase.strip                  # make the string lowercase and scrub white space on either side
          text = text.gsub(/[^a-z0-9\w]/, "-")        # make any character that is not nupermic or alphabetic into an underscore
          text = text.sub(/_+$/, "").sub(/^_+/, "")   # remove underscores on either end, caused by non-simplified characters
          text = text[0...obj.class.base_class.instance_variable_get('@permalink_length')]        # trim to length
        end
        text
      end

      # Returns the unique permalink string for the passed in object.
      def generate_permalink_for(obj)

        # Find the source for the permalink
        text = initial_permalink_text(obj)
        
        # scrub the text
        text = scrub_text(obj, text)
        
        # Attempt to find the object by the permalink
        found_object = obj.class.base_class.send("find_by_#{obj.class.base_class.instance_variable_get('@permalink_column_name')}", text)
        if found_object && found_object != obj
          num = 1

          # If we find the object we know there is a collision, so just add a number to the end until there is no collision
          while obj.class.base_class.send("find_by_#{obj.class.base_class.instance_variable_get('@permalink_column_name')}", text + num.to_s)
            num += 1
          end

          text = text + num.to_s
        end
        text
      end
    end
  
    module SingletonMethods
    end
    
    module InstanceMethods
      
      # Generate the permalink and assign it directly via callback
      def update_permalink
        updated_permalink = self.class.base_class.generate_permalink_for(self)
        return true if updated_permalink == self.permalink

        self.send("#{self.class.base_class.instance_variable_get('@permalink_column_name')}=", updated_permalink)
        true
      end
    end
  end
end

ActiveRecord::Base.send(:include, Acts::Permalink)
