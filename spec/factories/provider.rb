FactoryGirl.define do

  factory(:provider_amazon, :class => "ManageIQ::Providers::Amazon::Provider", :parent => :provider) do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
    end
  end
end
