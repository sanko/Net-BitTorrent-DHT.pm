# NAME

Net::BitTorrent::DHT - BitTorrent Mainline DHT implementation

# SYNOPSIS

```perl
use Net::BitTorrent::DHT;

my $dht = Net::BitTorrent::DHT->new(
    node_id_bin => pack('H*', '0123456789abcdef0123456789abcdef01234567'),
    port        => 6881,
    address     => '0.0.0.0' # Optional: bind to specific address
);

# Bootstrap the routing table
$dht->bootstrap();

# In your event loop:
while (1) {
    my ($new_nodes, $found_peers) = $dht->tick(0.1);
    # ... process results ...
}

# Or run in a blocking loop:
# $dht->run();
```

# DESCRIPTION

`Net::BitTorrent::DHT` implements the BitTorrent Mainline DHT protocol (BEP 5) with IPv6 extensions (BEP 32). It uses
[Algorithm::Kademlia](https://metacpan.org/pod/Algorithm%3A%3AKademlia) for its core routing logic and [Net::BitTorrent::Protocol::BEP03::Bencode](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03%3A%3ABencode) for wire
serialization.

# METHODS

## `new( node_id_bin => ..., [ port => 6881, address => ..., want_v4 => 1, want_v6 => 1, bep32 => 1, bep51 => 1, timeout => 0 ] )`

Constructor. `node_id_bin` must be a 20-byte binary string.

- `want_v4`

    Enable or disable IPv4 support. Defaults to 1.

- `want_v6`

    Enable or disable IPv6 support. Defaults to 1.

- `bep32`

    Enable or disable BEP 32 (IPv6 extensions). When enabled, `find_node` and `get_peers` responses will include both
    `nodes` and `nodes6` fields. Defaults to 1.

- `bep33`

    Enable or disable BEP 33 (DHT Scraping). When enabled, the node will support `scrape_peers` queries and
    `announce_peer` will include the `seed` flag. Defaults to 1.

- `bep44`

    Enable or disable BEP 44 (Storing Arbitrary Data in the DHT). When enabled, the node will support `get` and `put`
    queries for immutable and mutable data. Defaults to 1.

- `bep51`

    Enable or disable BEP 51 (Infohash Indexing). When enabled, the node will support `sample_infohashes` queries.
    Defaults to 1.

- `read_only`

    When set to a true value, the node will include the `ro` flag (BEP 43) in all queries, indicating that it should not
    be added to the routing tables of remote nodes. Defaults to 0.

## `bootstrap( )`

Seeds the routing table by querying a set of hardcoded bootstrap nodes (routers). This is typically the first method
called after instantiation to join the DHT network.

## `ping( $addr, $port )`

Sends a `ping` query to the specified address and port.

## `find_node_remote( $target_id, $addr, $port )`

Sends a `find_node` query for the specified 20-byte target ID.

## `get_peers( $info_hash, $addr, $port )`

Sends a `get_peers` query for the specified info-hash.

## `get_remote( $target, $addr, $port )`

Sends a `get` query (BEP 44) for the specified target.

## `put_remote( \%args, $addr, $port )`

Sends a `put` query (BEP 44). `\%args` must contain `v` (value) and for mutable data also `k` (public key), `sig`
(signature), `seq` (sequence number), and optionally `salt` and `cas`.

## `scrape_peers_remote( $info_hash, $addr, $port )`

Sends a `scrape_peers` query (BEP 33) for the specified info-hash.

## `sample_infohashes_remote( $target, $addr, $port )`

Sends a `sample_infohashes` query (BEP 51) to the specified address. `$target` is a 20-byte binary string.

## `export_state( )`

Returns a HASH reference containing the current node ID, routing tables (IPv4 and IPv6), peer storage, and hosted
mutable data. This is useful for persisting the DHT state between restarts.

## `import_state( $state )`

Restores the DHT state from a HASH reference previously returned by `export_state()`. This includes routing tables,
peer storage, and hosted mutable data.

## `tick( [ $timeout ] )`

Processes any incoming UDP packets. Returns three list references: `$new_nodes`, `$found_peers`, and `$data`.
`$new_nodes` is a list of newly discovered nodes. `$found_peers` is a list of discovered peers. `$data` is a hash
reference of data if a BEP 44 'get' response was received or BEP 51 samples if 'sample\_infohashes' response was
received. `$timeout` is the maximum time to wait for data (in seconds).

## `handle_incoming( )`

Reads a single packet from the socket and processes it. Returns the same three list references as `tick()`. Use this
if you are using your own event loop (e.g., `IO::Async`).

## `run( )`

Enters an infinite loop calling `tick()`.

# BEP 44 SUPPORT

BEP 44 (Storing Arbitrary Data in the DHT) requires an Ed25519 implementation for signing and verifying mutable data.
`Net::BitTorrent::DHT` automatically detects and uses one of the following modules, in order of preference:

- 1. [Crypt::PK::Ed25519](https://metacpan.org/pod/Crypt%3A%3APK%3A%3AEd25519)
- 2. [Crypt::Perl::Ed25519::PublicKey](https://metacpan.org/pod/Crypt%3A%3APerl%3A%3AEd25519%3A%3APublicKey)

If none of these modules are available, BEP 44 support will be automatically disabled (`bep44` will be set to 0).

# IPv6 SUPPORT

This module fully supports BEP 32. It correctly handles the `nodes6` field in responses and supports 18-byte compact
IPv6 peer addresses in `values`.

# EVENT LOOP INTEGRATION

This module is designed to be protocol-agnostic regarding the event loop.

## Using with IO::Select (Default)

Simply call `tick($timeout)` in your own loop.

## Using with IO::Async

```perl
my $handle = IO::Async::Handle->new(
    handle => $dht->socket,
    on_read_ready => sub {
        my ($nodes, $peers) = $dht->handle_incoming();
        # ...
    },
);
$loop->add($handle);
```

# SEE ALSO

[Algorithm::Kademlia](https://metacpan.org/pod/Algorithm%3A%3AKademlia), [Net::BitTorrent::Protocol::BEP03::Bencode](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03%3A%3ABencode)

[https://www.bittorrent.org/beps/bep\_0005.html](https://www.bittorrent.org/beps/bep_0005.html),  [https://www.bittorrent.org/beps/bep\_0032.html](https://www.bittorrent.org/beps/bep_0032.html)

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2023-2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.
