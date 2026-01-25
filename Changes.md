# Changelog

All notable changes to Net::BitTorrent::DHT will be documented in this file.

## [Unreleased]

### Added

- Pulled out of Net::BitTorrent::DHT for use in other DHTs.
- Supports IPv6 (BEP32)
- Can be backed by IO::Select or IO::Async

[v1.0.3] 2014-11-29

### Changed

- Declare Type::Standard dependency

[v1.0.2] 2014-06-26

### Changed

- Serve as a standalone node by default
- Update to NB::Protocol v1.0.2 and above

[v1.0.1] 2014-06-21

### Changed

- Generate local node id based on external IP (work in progress)
- Use a condvar in address resolver instead of forcing the event loop

[v1.0.0] 2014-06-21

- original version (broken from unstable Net::BitTorrent dist)
