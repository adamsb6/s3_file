if defined?(ChefSpec)
  ChefSpec.define_matcher :s3_file

  def create_s3_file(path)
    ChefSpec::Matchers::ResourceMatcher.new(:s3_file, :create, path)
  end
end
