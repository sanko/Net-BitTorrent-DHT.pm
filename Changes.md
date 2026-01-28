# Changelog

All notable changes to Net::BitTorrent::DHT will be documented in this file.

## [v2.0.4] - 2026-01-28

### Added

- Support for the `external_ip_detected` event.
- Automatic `node_id` rotation when a new external IP is detected (requires BEP 42).

### Fixed

- Improved `node_id` rotation logic to update both IPv4 and IPv6 routing tables.
- Fixed a crash in `_check_external_ip` when receiving full compact addresses (including ports).

## [v2.0.3] - 2026-01-27

### Changed

- Expose readers for `want_v4` and `want_v6`.

## [v2.0.2] - 2026-01-27

### Fixed

- Peers that attempt to update mutable data with an invalid signature (BEP 44) are now automatically blacklisted and ignored for the duration of the session.

## [v2.0.1] - 2026-01-27

### Added

- Client Identification support (the 'v' key) via the `v` constructor parameter.
- Support for the 'ip' field in responses (BEP 5), allowing remote nodes to discover their external IP.
- Support for the 'want' key in queries (BEP 32) to return specific node families.
- BEP 51 exposure with new `find_peers()`, `scrape()`, and `sample()` methods.

### Changed

- The `sample_infohashes` feature (BEP 51) can now be toggled via the `bep51` parameter.

## [v2.0.0] - 2026-01-26

This is a total rewrite. I was breaking apart the Kademlia stuff into smaller pieces for a larger, non-BitTorrent related project so I spent a day on this...

### Added

- Pulled out of Net::BitTorrent::DHT for use in other DHTs.
- Supports...
  - BEP05: Core DHT spec
  - BEP32: IPv6
  - BEP33: DHT scrape
  - BEP42: Secure DHT
  - BEP43: Readonly DHT node
  - BEP44: Arbitrary mutable/immutable data storage in the DHT network (very nice)
  - BEP51: Infohash indexing

## [v1.0.3] 2014-11-29

### Changed

- Declare Type::Standard dependency

## [v1.0.2] 2014-06-26

### Changed

- Serve as a standalone node by default
- Update to NB::Protocol v1.0.2 and above

## [v1.0.1] 2014-06-21

### Changed

- Generate local node id based on external IP (work in progress)
- Use a condvar in address resolver instead of forcing the event loop

## [v1.0.0] 2014-06-21

- original version (broken from unstable Net::BitTorrent dist)

[Unreleased]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v2.0.4...HEAD
[v2.0.4]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v2.0.3...v2.0.4
[v2.0.3]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v2.0.2...v2.0.3
[v2.0.2]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v2.0.1...v2.0.2
[v2.0.1]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v2.0.0...v2.0.1
[v2.0.0]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v1.0.3...v2.0.0
[v1.0.3]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v1.0.2...v1.0.3
[v1.0.2]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v1.0.1...v1.0.2
[v1.0.1]: https://github.com/sanko/Net-BitTorrent-DHT.pm/compare/v1.0.0...v1.0.1
[v1.0.0]: https://github.com/sanko/Net-BitTorrent-DHT.pm/releases/tag/v1.0.0
