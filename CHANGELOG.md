# Change Log

All notable changes to this project will be documented in this file.

## Unreleased Sprint 59

### Added
- Rewrite network and subnet parser to a new format [(#229)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/229)
- Rewrite EBS parser to a new format [(#228)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/228)
- Rewrite S3 parser to a new format [(#227)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/227)

## Fine RC-1

### Added
- Rewrite the instance parser to the new syntax [(#225)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/225)
- Rewrite stacks parser to the new syntax [(#223)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/223)
- Rewrite images parser to the new syntax [(#221)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/221)
- Rewrite parsing of flavors keypairs and azs to the new syntax [(#220)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/220)
- Remap `:name` parameter into `:bucket` parameter when creating new bucket [(#198)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/198)
- Use public flag we get from data rather than sending it explicitly [(#197)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/197)
- Add tags for VMs and Images [(#183)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/183)
- Add options for graph refresh [(#158)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/158)
- Adjust attribute set of newly created bucket [(#192)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/192)
- Add eu-west-2 and ap-south-1 regions [(#178)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/178)
- Enable dynamic cloud volume modifications [(#177)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/177)
- Increase minimum AWS version for modify_volume [(#176)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/176)
- Do vm targeted full refresh by default [(#174)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/174)
- New instance types [(#171)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/171)
- Maintain instance types [(#170)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/170)
- Support deletion of CloudObjectStoreContainer [(#144)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/144)
- Cloud volume operations [(#151)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/151)
- Support operation `create` for CloudObjectStoreContainer [(#172)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/172)
- List VMs from the same availability zone as volume [(#164)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/164)
- AWS SDK call `get_bucket_location` returns empty string [(#168)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/168)
- Set default Container and Object class when collecting inventory for the 1st time [(#165)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/165)
- Support deletion of CloudObjectStoreObject [(#152)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/152)
- Maintain instance types [(#170)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/170)
- Gather AWS labels and create CustomAttributes [(#162)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/162)
- Event parser can parse new format of target [(#160)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/160)
- Add amazon events to settings to display them in timelines [(#163)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/163)
- Support operation "clear" on CloudObjectStoreContainer [(#153)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/153)
- Add cloud volume snapshot operations for EBS manager [(#156)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/156)
- Add eu-west-2 and ap-south-1 regions [(#178)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/178)
- New instance types [(#171)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/171)
- Pass collector to persister to make targeted refresh work [(#149)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/149)
- Catch cloudwatch alarms [(#147)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/147)
- Use base classes for Inventory Collector Persistor and Parser [(#139)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/139)
- Amazon S3 objects inventorying [(#123)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/123)
- Add ca-central region #[113](https://github.com/ManageIQ/manageiq-providers-amazon/pull/113)
- Add links between cloud volumes and base snapshots #[112](https://github.com/ManageIQ/manageiq-providers-amazon/pull/112)
- Introduce Amazon S3 StorageManager ([#106](https://github.com/ManageIQ/manageiq-providers-amazon/pull/106))
- Introduce Amazon Block Storage  Manager (EBS) ([#101](https://github.com/ManageIQ/manageiq-providers-amazon/pull/101))
- Parse availability zone of an EBS volume ([#116](https://github.com/ManageIQ/manageiq-providers-amazon/pull/116))
- Collect inventory using 'inventory' abstraction in refresh ([#102](https://github.com/ManageIQ/manageiq-providers-amazon/pull/102))
- Introduce 'inventory' abstraction for fetching and storing inventory data ([#98](https://github.com/ManageIQ/manageiq-providers-amazon/pull/98))
- Map unknown event to automate to ConfigurationItemChangeNotification ([#93](https://github.com/ManageIQ/manageiq-providers-amazon/pull/93))

### Changed
- Filter out events in Settings instead of CloudManager [(#141)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/141)
- Use base classes for Inventory Collector Persistor and Parser [(#139)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/139)
- Increase minimum AWS version for modify_volume [(#176)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/176)
- Disabling a broken spec [(#148)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/148)
- Filter events using eventType instead of MessageType [(#142)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/142)
- Renamed refresh strategies [(#146)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/146)
- Remove validate_timeline [(#143)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/143)
- Queue EBS storage refresh after cloud inventory is saved ([#120](https://github.com/ManageIQ/manageiq-providers-amazon/pull/120))
- Rename Amazon block storage manager ([#107](https://github.com/ManageIQ/manageiq-providers-amazon/pull/107))
- Changes required after inventory refresh memory optimizations ([#109](https://github.com/ManageIQ/manageiq-providers-amazon/pull/109))
- Rename 'DTO' to 'Inventory' in refresh ([#95](https://github.com/ManageIQ/manageiq-providers-amazon/pull/95))

### Fixed
- Targeted refresh specs for orchestration stacks [(#214)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/214)
- Ensure managers change zone and provider region with cloud manager [(#212)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/212)
- Gracefully ignore and log errors when listing s3 objects [(#207)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/207)
- Return instead of next is causing unwanted break of Vm parsing [(#202)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/202)
- Add support snapshot_create to EBS cloud volume [(#196)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/196)
- Filter terminated instance properly [(#184)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/184)
- Suppress warning "toplevel constant referenced" [(#166)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/166)
- Set power state to shutting_down when rebooting an instance [(#145)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/145)
- Fix logger in Amazon EBS refresh parser [(#159)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/159)
- Fix connection of events to ems_ref ([#94](https://github.com/ManageIQ/manageiq-providers-amazon/pull/94))

### Removed
- Remove `require_nested :Runner` from NetworkManager::EventCatcher and NetworkManager::MetricsCollectorWorker [(#173)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/173)
