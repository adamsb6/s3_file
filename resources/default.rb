actions :create
attribute :path, :kind_of => String, :name_attribute => true
attribute :remote_path, :kind_of => String
attribute :bucket, :kind_of => String
attribute :aws_access_key_id, :kind_of => String, :default => nil
attribute :aws_secret_access_key, :kind_of => String, :default => nil
attribute :token, :kind_of => String, :default => nil
attribute :owner, :kind_of => [String, NilClass], :default => nil
attribute :group, :kind_of => [String, NilClass], :default => nil
attribute :mode, :kind_of => [String, NilClass], :default => nil

def initialize(*args)
  super
  @action = :create
end
