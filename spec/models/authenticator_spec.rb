describe Authenticator do
  describe '.for' do
    it "instantiates the matching class" do
      expect(Authenticator.for(:mode => 'amazon')).to be_a(Authenticator::Amazon)
    end
  end
end
