# Change Log

All notable changes to this project will be documented in this file.


## Unreleased - as of Sprint 57 end 2017-03-27

### Added
- Adjust attribute set of newly created bucket [(#192)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/192)
- Add eu-west-2 and ap-south-1 regions [(#178)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/178)
- Enable dynamic cloud volume modifications [(#177)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/177)
- Increase minimum AWS version for modify_volume [(#176)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/176)
- Do vm targeted full refresh by default [(#174)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/174)
- New instance types [(#171)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/171)
- Maintain instance types [(#170)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/170)

### Fixed
- Add support snapshot_create to EBS cloud volume [(#196)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/196)
- Filter terminated instance properly [(#184)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/184)

## Unreleased - as of Sprint 56 end 2017-03-13

### Added
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

### Changed
- Filter out events in Settings instead of CloudManager [(#141)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/141)
- Use base classes for Inventory Collector Persistor and Parser [(#139)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/139)
- Increase minimum AWS version for modify_volume [(#176)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/176)

### Removed
- Remove `require_nested :Runner` from NetworkManager::EventCatcher and NetworkManager::MetricsCollectorWorker [(#173)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/173)

### Fixed
- Suppress warning "toplevel constant referenced" [(#166)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/166)
- Set power state to shutting_down when rebooting an instance [(#145)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/145)
- Fix logger in Amazon EBS refresh parser [(#159)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/159)

## Unreleased - as of Sprint 55 end 2017-02-27

### Added

- Pass collector to persister to make targeted refresh work [(#149)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/149)
- Catch cloudwatch alarms [(#147)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/147)
- Use base classes for Inventory Collector Persistor and Parser [(#139)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/139)
- Amazon S3 objects inventorying [(#123)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/123)

### Changed
- Disabling a broken spec [(#148)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/148)
- Filter events using eventType instead of MessageType [(#142)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/142)
- Renamed refresh strategies [(#146)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/146)
- Remove validate_timeline [(#143)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/143)

## Unreleased - as of Sprint 53 end 2017-01-30

### Added
- Add ca-central region #[113](https://github.com/ManageIQ/manageiq-providers-amazon/pull/113)
- Add links between cloud volumes and base snapshots #[112](https://github.com/ManageIQ/manageiq-providers-amazon/pull/112)
- Introduce Amazon S3 StorageManager ([#106](https://github.com/ManageIQ/manageiq-providers-amazon/pull/106))
- Introduce Amazon Block Storage  Manager (EBS) ([#101](https://github.com/ManageIQ/manageiq-providers-amazon/pull/101))
- Parse availability zone of an EBS volume ([#116](https://github.com/ManageIQ/manageiq-providers-amazon/pull/116))


### Changed
- Queue EBS storage refresh after cloud inventory is saved ([#120](https://github.com/ManageIQ/manageiq-providers-amazon/pull/120))
- Rename Amazon block storage manager ([#107](https://github.com/ManageIQ/manageiq-providers-amazon/pull/107))
- Changes required after inventory refresh memory optimizations ([#109](https://github.com/ManageIQ/manageiq-providers-amazon/pull/109))


## Unreleased - as of Sprint 52 end 2017-01-14

### Added
- Collect inventory using 'inventory' abstraction in refresh ([#102](https://github.com/ManageIQ/manageiq-providers-amazon/pull/102))
- Introduce 'inventory' abstraction for fetching and storing inventory data ([#98](https://github.com/ManageIQ/manageiq-providers-amazon/pull/98))
- Map unknown event to automate to ConfigurationItemChangeNotification ([#93](https://github.com/ManageIQ/manageiq-providers-amazon/pull/93))

### Changed
- Rename 'DTO' to 'Inventory' in refresh ([#95](https://github.com/ManageIQ/manageiq-providers-amazon/pull/95))

### Fixed

- Fix connection of events to ems_ref ([#94](https://github.com/ManageIQ/manageiq-providers-amazon/pull/94))
