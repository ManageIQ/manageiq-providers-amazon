# Change Log

All notable changes to this project will be documented in this file.


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
