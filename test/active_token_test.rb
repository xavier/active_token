
require File.dirname(__FILE__) + '/test_helper.rb'

class ActiveTokenTest < Test::Unit::TestCase

  load_schema

  class User < ActiveRecord::Base
    has_token :made_of => ["Some neat Schopenhauer quote for the salt", :username, :password]
  end

  class SecretDocument < ActiveRecord::Base
    has_token :field => :key, :digest => 'MD5', :rounds => 5, :update => true do
      self.title + "salt" + 1_000_000.to_s
    end
  end
  
  class Invitation < ActiveRecord::Base
    has_token :made_of => [:id, :email, :created_at], :join_with => '---' do
      [1, 2, "three"]
    end
  end
  
  def setup
    @user       = User.new(:username => "rachel", :password => "unicorn")
    @doc        = SecretDocument.new(:title => "On Androids and Electric Sheeps", :body => "Once upon a time...")
    @invitation = Invitation.new(:email => 'alden@tyrell.corp')
    @_ = ActiveToken::DEFAULT_GLUE
  end  
  
  def test_default_settings
    assert_equal 'token', User.active_token_field
    assert_equal ActiveToken::DEFAULT_NUMBER_OF_ROUNDS, User.active_token_rounds
    assert_equal Digest::SHA1, User.active_token_digest_algorithm
    assert_equal ActiveToken::DEFAULT_GLUE, User.active_token_glue
  end
  
  def test_custom_field_name
    assert_equal 'key', SecretDocument.active_token_field
    assert @doc.save
    assert_hexdigest @doc.key
  end
  
  def test_custom_glue
    assert_equal '---', Invitation.active_token_glue
  end
  
  def test_custom_digest_and_rounds
    assert_equal 5, SecretDocument.active_token_rounds
    assert_equal Digest::MD5, SecretDocument.active_token_digest_algorithm
  end
  
  def test_application_of_rounds
    restore_active_token_rounds = User.active_token_rounds
    User.active_token_rounds = 1
    h1 = @user.hash_token('text to hash')
    User.active_token_rounds = 5
    h2 = @user.hash_token('text to hash')
    assert_hexdigest h1
    assert_hexdigest h2
    assert_not_equal h1, h2
    User.active_token_rounds = restore_active_token_rounds # Be nice with the next tests
  end
  
  def test_collect_token_contents_made_of
    assert_equal "Some neat Schopenhauer quote for the salt#{@_}rachel#{@_}unicorn", @user.collect_token_contents
  end
  
  def test_collect_token_contents_block
    assert_equal "#{@doc.title}salt1000000", @doc.collect_token_contents
  end

  def test_collect_token_contents_made_of_and_block
    now = Time.now
    @invitation.id = 123
    @invitation.created_at = now
    assert_match /^\d+\-\-\-alden@tyrell\.corp\-\-\-#{Regexp.escape(now.to_s)}\-\-\-1\-\-\-2\-\-\-three$/, @invitation.collect_token_contents
  end
  
  def test_user
    assert @user.save
    assert_hexdigest @user.token, 40
  end
  
  def test_no_update
    assert @user.save
    first_token = @user.token
    assert @user.update_attributes(:username => "zhora")
    assert_equal first_token, @user.token
  end
  
  def test_update
    assert @doc.save
    first_key = @doc.key
    assert @doc.update_attributes(:title => "Untitled")
    assert_not_equal first_key, @doc.key
  end
  
  def test_user_made_of
    @user.save
    assert_hexdigest @user.token, 40 # SHA1
  end
  
  def test_block
    @invitation.save
    assert_hexdigest @invitation.token, 32 # MD5
  end

  def test_invitation
    @invitation.save
    assert_hexdigest @invitation.token, 40 # SHA1
  end
  
  def test_with_nil_values
    @user.username = nil
    @user.save
    assert_hexdigest @user.token
  end
  
  protected
  
  def assert_hexdigest(s, length = nil)
    if length
      assert_match /[0-9a-f]{#{length}}/, s, "Expected to be string of #{length} hex digits"
    else
      assert_match /[0-9a-f]+/, s, "Expected to be a string of hex digits"
    end
  end
  
end
