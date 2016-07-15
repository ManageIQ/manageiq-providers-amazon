source 'https://rubygems.org'

# Declare your gem's dependencies in manageiq-providers-amazon.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

group :test do
  gem "codeclimate-test-reporter", :require => false
end

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

gem "awesome_spawn",           "~> 1.3",            :require => false
gem "sys-uname",               "~>1.0.1",           :require => false
gem 'sys-proctable',           "~> 1.0",            :require => false
gem "log4r",                   "=1.1.8",            :require => false
gem "uuidtools",               "~>2.1.3",           :require => false
gem "rails",                           "~> 5.0.x", :git => "git://github.com/rails/rails.git", :branch => "5-0-stable"
gem "rspec-rails",      "~>3.5.x"
gem "ezcrypto",                "=0.7",              :require => false
gem "more_core_extensions",    "~>3.0.0",           :require => false

if RbConfig::CONFIG["host_os"].include?("linux")
  gem "linux_block_device", ">=0.1.0", :require => false
end

gem "memory_buffer",           ">=0.1.0",           :require => false
gem "addressable",             "~> 2.4",            :require => false
gem "pg",                      "~>0.18.2",          :require => false
gem "ruport",                         "=1.7.0",                       :git => "git://github.com/ManageIQ/ruport.git", :tag => "v1.7.0-3"
gem "config",                          "~>1.1.0", :git => "git://github.com/ManageIQ/config.git", :branch => "overwrite_arrays"

gem "gettext_i18n_rails",             "~>1.4.0"
gem "gettext_i18n_rails_js",          "~>1.0.3"
gem "fast_gettext",                   "~>1.1.0"
gem "high_voltage",                   "~>2.4.0"
gem "omniauth",                       "~>1.3.1",   :require => false
gem "omniauth-google-oauth2",         "~>0.2.6"
gem "paperclip",                      "~>4.3.0"
gem "ruby_parser",                    "~>3.7",     :require => false
gem "secure_headers",                 "~>3.0.0"
gem "sprockets-es6",                  "~>0.9.0",  :require => "sprockets/es6"
gem "linux_admin",             "~>0.17.0",          :require => false
gem "memoist",                 "~>0.14.0",          :require => false
gem "default_value_for",              "~>3.0.2.alpha-miq.1", :git => "git://github.com/jrafanie/default_value_for.git", :branch => "rails-50" # https://github.com/FooBarWidget/default_value_for/pull/57
gem "dalli",                          "~>2.7.4",   :require => false
gem "binary_struct",           "~> 2.1",            :require => false
gem "handsoap", "~>0.2.5", :require => false, :git => "git://github.com/ManageIQ/handsoap.git", :tag => "v0.2.5-3"
gem "iniparse",                                     :require => false
gem "acts_as_tree",                   "~>2.1.0"  # acts_as_tree needs to be required so that it loads before ancestry
gem "ancestry",                       "~>2.1.0",   :require => false
gem "factory_girl",     "~>4.5.0",  :require => false
gem "timecop",       "~>0.7.3",     :require => false
gem "vcr",           "~>2.6",       :require => false
gem "webmock",       "~>1.12",      :require => false
gem "capybara",         "~>2.5.0",  :require => false
gem "rails-controller-testing",        :require => false
gem "bcrypt",                  "~> 3.1.10",         :require => false
gem "hamlit-rails",                   "~>0.1.0"
gem "hamlit",                         "~>2.0.0",   :require => false
gem "image-inspector-client",  "~>1.0.2",           :require => false
gem "kubeclient",              "=1.1.3",            :require => false
gem "ansible_tower_client",           "~>0.3.0",   :require => false
gem "rubywbem",            :require => false, :git => "git://github.com/ManageIQ/rubywbem.git", :branch => "rubywbem_0_1_0"
gem "net_app_manageability",          ">=0.1.0",   :require => false
gem "coveralls",                    :require => false
gem "hawkular-client",         "=2.0.0",            :require => false
gem "rbvmomi",                 "~>1.8.0",           :require => false
