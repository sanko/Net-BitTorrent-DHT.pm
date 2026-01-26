# Net::BitTorrent::DHT Development Roadmap

## Phase 1: Core Connectivity & Security
- [x] **BEP 32: IPv6 Support for DHT**
    - [x] Manage dual routing tables (v4 and v6).
    - [x] Ensure `get_peers` returns both `nodes` and `nodes6`.
    - [x] Handle dual-stack preference and toggles.
- [x] **BEP 42: DHT Security Extension**
    - [x] Implement IP-based Node ID generation (CRC32c scheme).
    - [x] Add validation logic for incoming nodes in `add_peer`.
    - [x] Enforce security requirements for routing table updates.
    - [x] **Documentation & Unit Tests** for CRC32c and Security logic.

## Phase 2: Feature Extensions
- [x] **BEP 33: DHT Scraping**
    - [x] Add `scrape_peers` query support.
    - [x] Update `peer_storage` to handle seed/leecher count estimates.

## Phase 3: Advanced Storage
- [x] **BEP 44: Storing Arbitrary Data in the DHT**
    - [x] Implement Ed25519 signatures for mutable data.
    - [x] Implement sequence number management and storage.
    - [x] Support immutable data blobs.
    - [ ] Store/restore public key

## Phase X: Bonus Material
- [x] **BEP 51: DHT Infohash Indexing**
    - [x] Implement `sample_infohashes` query.
    - [x] Track and sample popular info-hashes.
- [x] **BEP 43: Read-only DHT nodes**
    - [x] Add `ro` flag support to queries.
- [ ] **BEP 5: DHT Maintenance**
    - [ ] Implement node ID rotation (though BEP 42 makes this harder).
    - [ ] Node ID, peers, nodes, BEP44 pub keys, etc. export and restore (rejoin without bootstrapping)
