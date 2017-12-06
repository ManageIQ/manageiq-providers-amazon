describe :placeholders do
  include_examples :placeholders, ManageIQ::Providers::Amazon::Engine.root.join('locale').to_s
end
