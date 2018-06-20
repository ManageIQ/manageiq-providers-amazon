# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 88 ending 2018-06-18

### Added
- Add display name for flavor [(#454)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/454)
- handle volume snapshot status changes [(#439)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/439)

## Unreleased as of Sprint 87 ending 2018-06-04

### Added
- Explicitly disable ems_network_new creation [(#448)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/448)
- Add endpoint support to raw_connect [(#444)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/444)

## Unreleased as of Sprint 86 ending 2018-05-21

### Fixed
- disable special regions [(#443)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/443)

## Gaprindshavili-3 released 2018-05-15

### Added
- AWS memory usage collection [(#393)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/393)

### Fixed
- Raise Exception if AMI not visible [(#411)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/411)
- Cleanup Smartstate Requests When AMI Unavailable for Agent [(#412)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/412)
- Updated flavors to include m5 instances [(#420)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/420)
- Fixes to add a retry logic in EC2 instance creation when IAM role is not ready [(#422)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/422)
- Added instance update event handling [(#415)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/415)
- Fixes VPC selection to make sure it has internet gateway attached. [(#424)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/424)
- Fix default filter for public images [(#425)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/425)
- Add patch to aws-sdk-core to fix auth bug [(#432)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/432)

## Unreleased as of Sprint 85 ending 2018-05-07

### Added
- load regions list from aws-sdk gem's source [(#436)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/436) 

### Changed
- Renamed method for consistency reasons [(#419)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/419)

## Gaprindshavili-2 released 2018-03-06

### Fixed
- Fix refresh for stack without parameters [(#410)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/410)

## Unreleased as of Sprint 80 ending 2018-02-26

### Fixed
- Return created topic [(#409)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/409)

## Unreleased as of Sprint 79 ending 2018-02-12

### Added 
- Add display_name() for Network Router model [(#406)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/406)
- Use proper nested references in parser [(#383)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/383)

### Fixed
- Raise exceptions if SSH command fail [(#405)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/405)

## Gaprindshavili-1 - Released 2018-01-31

### Added
- Add Gaprindashvili translations [(#368)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/368)
- Suggested Changes from Initial Implementation [(#360)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/360)
- Parse aws config orchestration stack event [(#310)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/310)
- Add routers to full refresh [(#304)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/304)
- Add raw_delete_snapshot to CloudVolumeSnapshot model [(#277)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/277)
- Improve instance_types.rake logic [(#301)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/301)
- Add YAML support for Amazon OrchestrationTemplate [(#298)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/298)
- Prefix API based events so we can identify them easily [(#293)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/293)
- Turn on graph refresh with targeted refresh as default [(#290)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/290)
- Support custom instance_types [(#289)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/289)
- Overriding queue name to generate an array of queue names [(#280)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/280)
- Enable to save key_pair in Authentication [(#268)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/268)
- Enable SSA for AWS Images [(#266)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/266)
- Allow raw_connect to validate the connection and decrypt the password [(#264)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/264)
- Handle SSA Response from AWS Scanning Instance [(#267)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/267)
- Collect encryption status of cloud volume snapshot [(#259)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/259)
- Simplify TargetCollection Persistor by using IC configurations [(#255)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/255)
- Leverage builder params to provide ems id and defaults [(#253)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/253)
- Upgrade aws-sdk to 2.9.7 [(#252)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/252)
- Initial Changes to Amazon Provider for SSA Support [(#251)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/251)
- Collect IOPS and encryption status of cloud volume [(#211)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/211)
- Bump ruby to 2.3.3 and add 2.4.1 [(#245)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/245)
- Refresh port and floating ip for a lb [(#244)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/244)
- Rewrite network ports and floating ips parser to a new format [(#233)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/233)
- Rewrite load balancers parser to a new format [(#231)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/231)
- Rewrite network and subnet parser to a new format [(#229)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/229)
- Rewrite EBS parser to a new format [(#228)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/228)
- Rewrite S3 parser to a new format [(#227)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/227)

### Fixed
- Correct status for network [(#373)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/373)
- Added supported_catalog_types [(#377)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/377)
- Refresh operating system and fix normalized guest os [(#376)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/376)
- exclude on_failure and timeout_in_minutes when update a stack [(#350)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/350)
- Fix no security group exists at the first time [(#363)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/363)
- Always sort ems queue names before hitting miq_queue [(#361)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/361)
- Handle possibility of empty string for Name tag [(#322)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/322)
- Fix KeyPair create and import actions [(#365)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/365)
- Choose VPC with enabled DNS support to deploy SSA Agent [(#354)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/354)
- Correctly parse key pair reference [(#311)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/311)
- Compact targeted refresh references [(#308)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/308)
- Add OrchestrationParameterMultiline constraints to options that require a text area [(#307)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/307)
- Add nil checks for stack [(#291)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/291)
- Adjust test result to match new data_type [(#272)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/272)
- Handle empty string in image name tags [(#273)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/273)
- Parse timestamp for aws alarm events [(#246)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/246)
- Combine registry and image together when registry needs. [(#353)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/353)
- Implement tag mapping in graph refresh [(#382)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/382)
- Fixes to cleanup agents if AgentCoordinatorWorker is restarted [(#381)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/381)
- Handle possibility of empty string for Name tag [(#322)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/322)
- Use name to create key pair [(#370)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/370)
- Suggested Changes from Initial Implementation [(#360)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/360)
- Moved AWS_API_CALL_TerminateInstances from addition to deletion category [(#402)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/402)
- Don't dependent => destroy child_managers [(#401)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/401)
- Fixes to send job defined scanning categories in request message [(#389)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/389)

### Removed
- Remove Amazon provider discovery [(#306)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/306)

## Unreleased as of Sprint 78 ending 2018-01-29

### Added
- Migrate model display names from locale/en.yml to plugin [(#398)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/398)
- Added Paris (EU) region [(#392)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/392)

### Fixed
- Fix network_parser after the indexes refactoring [(#375)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/375)

## Unreleased as of Sprint 76 ending 2018-01-01

### Fixed
- Add cleanup logic to remove zombie instance in unexpected cases [(#367)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/367)

## Unreleased as of Sprint 73 ending 2017-11-13

### Added
- Turn on batch saving by default [(#292)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/292)

## Unreleased as of Sprint 72 ending 2017-10-30

### Added
- Amazon SSA Response Handling Thread [(#319)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/319)
- Add agent coordinator for smartstate support [(#318)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/318)

### Fixed
- Use Concern for ResponseThread include [(#343)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/343)
- Add ssa_queue public method to the coordinator [(#340)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/340)
- Unpriveleged user can't docker login [(#337)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/337)
- Login is for the docker_registry not the image [(#333)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/333)
- Add wait_until_exists on instance_profile creation [(#332)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/332)
- Raise the intended message [(#326)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/326)
- Include ResponseThread in Runner [(#325)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/325)

## Fine-3

### Fixed
- Support deletion of S3 folders [(#226)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/226)
- Prevent volume update with no modifications [(#249)](https://github.com/ManageIQ/manageiq-providers-amazon/pull/249)

## Fine-1

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

## Initial changelog added
