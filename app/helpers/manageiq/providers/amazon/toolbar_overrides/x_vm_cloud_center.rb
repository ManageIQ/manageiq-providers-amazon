module ManageIQ
  module Providers
    module Amazon
      module ToolbarOverrides
        class XVmCloudCenter < ::ApplicationHelper::Toolbar::Override
          button_group('amazon_stuff', [
            select(
              :amazon_stuff,
              'fa fa-cog fa-lg',
              t = N_('Amazon Stuff'),
              t,
              :items => [
                button(
                  :amazon_do_start_instance,
                  'fa fa-refresh fa-lg',
                  N_('Do something to this Instance'),
                  N_('Start this Instance'),
                  :confirm => N_("Really wanna do something?"),
                  :klass   => ApplicationHelper::Button::ButtonWithoutRbacCheck,
                ),
                button(
                  :amazon_do_stop_instance,
                  'fa fa-search fa-lg',
                  N_('Do something more to this Instance'),
                  N_('Stop this Instance'),
                  :confirm => N_("Still not enough?"),
                  :klass   => ApplicationHelper::Button::ButtonWithoutRbacCheck,
                ),
                button(
                  :amazon_do_stop_instance,
                  'fa fa-search fa-lg',
                  N_('Do something more to this Instance'),
                  N_('Create security group'),
                  :klass   => ApplicationHelper::Button::ButtonWithoutRbacCheck,
                ),
              ]
            )
          ])
        end
      end
    end
  end
end
