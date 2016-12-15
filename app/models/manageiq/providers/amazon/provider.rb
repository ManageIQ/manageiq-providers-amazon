class ManageIQ::Providers::Amazon::Provider < ::Provider
  validates :name, :presence => true, :uniqueness => true
end
