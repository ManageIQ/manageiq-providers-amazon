module ManageIQ
  module Providers
    module Amazon
      module ToolbarOverrides
        class EmsCloudCenter < ::ApplicationHelper::Toolbar::Override
          button_group('magic', [
            button(
              :magic,
              'fa fa-magic fa-lg',
              t = N_('Magic'),
              t,
              :data  => {'function'      => 'sendDataWithRx',
                         'function-data' => {:controller     => 'provider_dialogs', # this one is required
                                             :button         => :magic,
                                             :modal_title    => N_('Create a Security Group'),
                                             :component_name => 'CreateAmazonSecurityGroupForm'}.to_json},
              :klass => ApplicationHelper::Button::ButtonWithoutRbacCheck),
            button(
              :magic_api,
              'fa fa-magic fa-lg',
              t = N_('API call'),
              t,
              :data  => {'function'      => 'sendDataWithRx',
                         'function-data' => {:controller      => 'provider_dialogs', # this one is required
                                             :button          => :magic_api,
                                             :success_message => N_('API succesfully called'),
                                             :entity_name     => 'provider',
                                             :action_name     => 'foobar'}.to_json},
              :klass => ApplicationHelper::Button::ButtonWithoutRbacCheck),
            button(
              :magic_player,
              'fa fa-magic fa-lg',
              t = N_('Magic player'),
              t,
              :data  => {'function'      => 'sendDataWithRx',
                         'function-data' => {:controller  => 'provider_dialogs', # this one is required
                                             :button      => :magic_player,
                                             :dialog_name => 'test',
                                             :dialog_title => N_('Magic Provider Dialog'),
                                             :class       => 'ManageIQ::Providers::Amazon',
                        }.to_json},
              :klass => ApplicationHelper::Button::ButtonWithoutRbacCheck),
          ])
        end
      end
    end
  end
end
