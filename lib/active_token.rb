# ActiveToken

module ActiveToken
  
  # Factory settings
  DEFAULT_DIGEST_ALGORITHM = 'SHA1'
  DEFAULT_GLUE             = '///'
  DEFAULT_NUMBER_OF_ROUNDS = 2
  
  # :nodoc:
  def self.included(base)
     base.send :extend, ClassMethods
  end
  
  module ClassMethods
    
    # Available options are
    # [:field]      the column name for the token (default: <tt>token</tt>)
    # [:made_of]    an array of symbols (for the record attributes and methods) or strings (for salt and constant values)
    # [:join_with]  a string to piece the different source elements together (default: "///")
    # [:digest]     the name of the Digest model to use to generate the token (default: "SHA1")
    # [:rounds]     the number of times the digest algorithm will be run (default: 2)
    # 
    # The method also accepts a block which should return either a string or an array of objects implementing <tt>to_s</tt>
    #
    # Examples:
    #
    #   class User < ActiveRecord::Base
    #     has_token :made_of => [:username, :password, :created_at]
    #   end
    #         
    #   class Account < ActiveRecord::Base
    #     has_token :made_of => [:login, :password, :created_at], :digest => 'MD5', :rounds => 5
    #   end
    #
    #   class Invitation < ActiveRecord::Base
    #      has_token :join_with => "-*-" do
    #        ["#{email}#{Time.now}", rand(1_000_000)]
    #      end
    #   end
    #
    
    def has_token(options = {}, &block)
      
      cattr_accessor :active_token_field
      self.active_token_field = (options[:field] || :token).to_s
      
      cattr_accessor :active_token_digest_algorithm
      self.active_token_digest_algorithm = Digest.const_get(options[:digest] || DEFAULT_DIGEST_ALGORITHM)

      cattr_accessor :active_token_made_of
      self.active_token_made_of = options[:made_of] || []

      cattr_accessor :active_token_rounds
      self.active_token_rounds = options[:rounds] || DEFAULT_NUMBER_OF_ROUNDS
      
      cattr_accessor :active_token_glue
      self.active_token_glue = options[:join_with] || DEFAULT_GLUE
      
      cattr_accessor :active_token_block
      self.active_token_block = block

      send :include, InstanceMethods
      
      after_create :assign_token!
      after_validation_on_update :assign_token if options[:update]
    end
    
  end
  
  module InstanceMethods
    
    # Create one clear text string from all the declared token elements
    def collect_token_contents
      s = self.class.active_token_made_of.map { |e| e.is_a?(Symbol) ? self.send(e) : e.to_s }
      if b = self.class.active_token_block
        s << instance_eval(&b)  
      end
      s.flatten.join(self.class.active_token_glue)
    end
    
    # Transform the clear text token elements into an opaque string.
    # Override this if you want to use an alternate hashing method
    def hash_token(s)
      alg = self.class.active_token_digest_algorithm
      h = collect_token_contents
      self.class.active_token_rounds.times { h = alg.hexdigest(h) }
      h
    end
    
    # Build a new token
    def build_token
      hash_token(collect_token_contents)
    end
    
    # Assign a freshly rebuilt token but do not save the record
    def assign_token
      write_attribute(self.class.active_token_field, build_token)
    end
    
    # Rebuild, assign and save the token
    def assign_token!
      assign_token
      save!
    end
    
  end
  
end

ActiveRecord::Base.send :include, ActiveToken
