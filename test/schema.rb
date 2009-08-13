ActiveRecord::Schema.define(:version => 0) do
  
  create_table :users, :force => true do |t|
    t.string   :username
    t.string   :password
    t.datetime :created_at
    t.string   :token
  end
  
  create_table :secret_documents, :force => true do |t|
    t.string  :title
    t.text    :body
    t.string  :key
  end

  create_table :invitations, :force => true do |t|
    t.string  :email
    t.datetime :created_at
    t.string  :token
  end

end