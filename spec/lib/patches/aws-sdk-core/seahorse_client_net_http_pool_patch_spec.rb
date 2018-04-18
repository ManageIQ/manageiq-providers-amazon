require 'aws-sdk'
require 'patches/aws-sdk-core/seahorse_client_net_http_pool_patch'

describe Seahorse::Client::NetHttp::ConnectionPool do
  describe "#start_session (monkey patched)" do
    it "is now defined in the patch file" do
      patch_file      = File.join(%w[lib patches aws-sdk-core seahorse_client_net_http_pool_patch.rb])
      patch_filepath  = ManageIQ::Providers::Amazon::Engine.root.join(patch_file).to_s
      source_location = subject.method(:start_session).source_location

      expect(source_location.first).to eq(patch_filepath)
    end
  end
end
