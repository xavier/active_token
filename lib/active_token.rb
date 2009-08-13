# ActiveToken

module ActiveToken
  
  DEFAULT_DIGEST_ALGORITHM = 'SHA1'
  DEFAULT_GLUE             = '///'
  DEFAULT_NUMBER_OF_ROUNDS = 2
  
  def self.included(base)
     base.send :extend, ClassMethods
  end
  
  module ClassMethods
    
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
    
    # Transform the clear text token elements into an opaque string
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
    
    # Assign a freshly rebuilt token but do not save
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

# Mix and blend
ActiveRecord::Base.send :include, ActiveToken
