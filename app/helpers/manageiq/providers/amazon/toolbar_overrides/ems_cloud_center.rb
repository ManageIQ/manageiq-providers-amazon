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
              :magic,
              'fa fa-magic fa-lg',
              t = N_('API call'),
              t,
              :data  => {'function'      => 'sendDataWithRx',
                         'function-data' => {:controller      => 'provider_dialogs', # this one is required
                                             :button          => :magic,
                                             :success_message => N_('API succesfully called'),
                                             :entity_name     => 'provider',
                                             :action_name     => 'foobar'}.to_json},
              :klass => ApplicationHelper::Button::ButtonWithoutRbacCheck),
            button(
              :magic_dialog,
              'fa fa-magic fa-lg',
              t = N_('Magic'),
              t,
              :data  => {'function'      => 'sendDataWithRx',
                         'function-data' => {:controller => 'provider_dialogs', # this one is required
                                             :button     => :magic_dialog}.to_json},
              :klass => ApplicationHelper::Button::ButtonWithoutRbacCheck),
          ])
        end
      end
    end
  end
end
