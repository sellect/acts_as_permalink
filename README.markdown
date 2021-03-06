# Acts As Permalink

Manages permalink field on an ActiveRecord model to be used in place of the id field in Rails.

Written by Kevin McPhillips (kmcphillips) in 2009.

Last updated March 2012.

[http://github.com/kmcphillips/acts_as_permalink](http://github.com/kmcphillips/acts_as_permalink)

[github@kevinmcphillips.ca](mailto:github@kevinmcphillips.ca)


## Usage

The gem is on RubyGems:

    gem 'acts_as_permalink'

And then just call it in your model:

    class Post < ActiveRecord::Base
      acts_as_permalink
    end

That's about it. 
The plugin expects string fields to be used to save the permalink on the model and to use as a source for the permalink. It defaults to use the fields named "title" and "permalink" which can be overridden by options:

    :from        =>  :title       # Name of the active record column or function used to generate the permalink
    :to          =>  :permalink   # Name of the column where the permalink will be stored
    :max_length  =>  60           # Maximum number of characters the permalink will be

So, for example you have want to store your permalink in a column called "path_name" and you want to generate your permalink using first and last name, and you want to restrict it to 40 characters, your model would look like:

    class User < ActiveRecord::Base
      acts_as_permalink :from => :full_name, :to => :path, :max_length => 40

      def full_name
        first_name + last_name
      end
    end


## Tests

Just run:
  
    rspec


## History

* 0.4.0  --  Rails 4 support.

* 0.3.2  --  Fixed regression in STI support.

* 0.3.1  --  Rails 3.2 support.

* 0.3.0  --  Fixed collision problem with single table inheritance models. Removed dependency on andand gem.

