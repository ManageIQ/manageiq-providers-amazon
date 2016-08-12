Vmdb::Gettext::Domains.add_domain('ManageIQ_Providers_Amazon',
  ManageIQ::Providers::Amazon::Engine.root.join('locale').to_s,
  :po)
