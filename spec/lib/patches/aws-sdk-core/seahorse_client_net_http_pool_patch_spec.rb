require 'aws-sdk'
require 'patches/aws-sdk-core/seahorse_client_net_http_pool_patch'

describe Seahorse::Client::NetHttp::ConnectionPool do
  describe "#start_session (monkey patched)" do
    let(:patch_file)      { File.join(%w(lib patches aws-sdk-core seahorse_client_net_http_pool_patch.rb)) }
    let(:patch_filepath)  { ManageIQ::Providers::Amazon::Engine.root.join(patch_file).to_s }
    let(:source_location) { subject.method(:start_session).source_location }

    it "is now defined in the patch file" do
      expect(source_location.first).to eq(patch_filepath)
    end

    # This spec exists to confirm that the monkey patch we are doing to
    # Seahorse::Client::NetHttp::ConnectionPool#start_session is still valid by
    # comparing the source code of origial method to the patch code.
    #
    # Patch code for this can be found here:
    #
    #     lib/patches/aws-sdk-core/seahorse_client_net_http_pool_patch.rb
    #
    # If this spec fails, make sure to check the difference between the patched
    # code and what is in the original gem, and make the necessary changes so
    # the only changes are to the http_proxy.user and http_proxy.password
    # lines.
    it "only changes the necessary lines" do
      # How this works:
      #
      # We can basically assume with our current patch that the line counts for
      # the method will be the same, so don't try and lex the file to get the
      # method definition, just calculate it from a known quantity (from the
      # patch itself)
      #
      #   * patch_code is determined by taking the source_location line and
      #     reading up to the 5th to last line in the file, since we know that
      #     is the `end` statement of the method definition.
      #   * original_last_lineno is determined by determining taking the line
      #     number from the @_original_start_session_source_loc, and reading
      #     the number of lines from the original gem source equal to the total
      #     lines from the `patch_code`
      #
      # If the number of lines is off between the patch_code and the original,
      # then it will fail, and that is also acceptable since the changes we
      # made in the patch were done "inline" when compared to the original.
      patch_code = File.readlines(patch_filepath)[source_location[1] - 1..-5].join("")

      original_file, original_lineno = described_class.instance_variable_get(:@_original_start_session_source_loc)
      original_last_lineno = original_lineno + patch_code.lines.count - 1
      original_code = File.readlines(original_file)[original_lineno - 1..original_last_lineno - 1].join("")

      # Expect lines 1 through 9 to be the same in both code paths
      expect(patch_code.lines[0..8].join).to   eq(original_code.lines[0..8].join)

      # Expect lines 12 onward to be the same in both code paths
      expect(patch_code.lines[11..-1].join).to eq(original_code.lines[11..-1].join)
    end
  end
end
