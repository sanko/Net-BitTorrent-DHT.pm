# NAME

Net::BitTorrent::DHT - BitTorrent Mainline DHT implementation

# SYNOPSIS

```perl
use Net::BitTorrent::DHT;
use Net::BitTorrent::DHT::Security;

# Initialize security and generate a BEP 42 compliant ID
my $security = Net::BitTorrent::DHT::Security->new();
my $node_id  = $security->generate_node_id('12.34.56.78'); # Use your external IP

# Create the DHT instance
my $dht = Net::BitTorrent::DHT->new(
    node_id_bin => $node_id,
    port        => 6881,
    v           => 'NB01' # Client version
);

# Join the network
$dht->bootstrap();

# Main Loop
while (1) {
    # Process packets with a 100ms timeout
    my ($new_nodes, $found_peers, $data) = $dht->tick(0.1);

    # Handle discovered peers
    for my $peer (@$found_peers) {
        printf "Discovered peer: %s\n", $peer->to_string;
    }

    # Handle BEP 44 / 51 data
    if ($data) {
         # ... handle scrape, get, or sample results
    }

    # Periodic tasks (e.g. search for an infohash)
    # $dht->find_peers($info_hash) if $should_search;
}
```

# DESCRIPTION

`Net::BitTorrent::DHT` is a feature-complete implementation of the BitTorrent Mainline DHT protocol. It supports IPv4,
IPv6 (BEP 32), Security Extensions (BEP 42), Scrapes (BEP 33), Arbitrary Data Storage (BEP 44), and Infohash Indexing
(BEP 51).

# CONSTRUCTOR

## `new( %args )`

Creates a new DHT node instance.

```perl
my $dht = Net::BitTorrent::DHT->new(
    port    => 6881,
    want_v6 => 1,
    bep44   => 1
);
```

- `node_id_bin`

    A 20-byte binary string representing the local node ID. Defaults to a randomly generated ID if not provided. Note that
    if BEP 42 is enabled, this ID may be automatically rotated if a new external IP is detected.

- `port`

    The UDP port to listen on for DHT traffic. Defaults to `6881`.

- `address`

    The local IP address to bind the UDP socket to. Defaults to all available interfaces (`0.0.0.0` and `::`).

- `want_v4`

    Enable or disable support for the IPv4 address family. Defaults to `1`.

- `want_v6`

    Enable or disable support for the IPv6 address family. Defaults to `1`.

- `v`

    A 4-byte client version string (BEP 20) used to identify the software to other nodes. Identifying strings are
    conventionally two characters followed by two version digits (e.g. `NB01`).

- `bep32`

    Enable or disable support for IPv6 nodes and peers (BEP 32). Defaults to `1`.

- `bep33`

    Enable or disable DHT Scrapes (BEP 33), allowing queries for swarm seeder/leecher counts. Defaults to `1`.

- `bep42`

    Enable or disable DHT Security Extensions (BEP 42), which includes node ID validation and automatic ID rotation.
    Defaults to `1`.

- `bep44`

    Enable or disable Arbitrary Data Storage (BEP 44) for storing and retrieving mutable and immutable data. Defaults to
    `1`.

- `bep51`

    Enable or disable Infohash Indexing (BEP 51), which allows nodes to sample infohashes stored on the network. Defaults
    to `1`.

- `read_only`

    If set to `1`, the node will signal to other peers that it should not be added to their routing tables (BEP 43). This
    is useful for low-bandwidth clients or those behind restrictive NATs. Defaults to `0`.

- `boot_nodes`

    An array reference of `[[host, port], ...]` used for the initial bootstrap process. Defaults to a list of standard
    public DHT routers including `router.bittorrent.com` and `router.utorrent.com`.

- `node_id_rotation_interval`

    The interval, in seconds, at which the node ID should be automatically rotated if BEP 42 is enabled. Defaults to
    `7200` (2 hours).

# METHODS

## `bootstrap( )`

Queries bootstrap nodes to join the network.

```
$dht->bootstrap( );
```

## `tick( [$timeout] )`

The heartbeat of the DHT. Call this in your loop to process I/O. This method also handles automatic node ID rotation if
the rotation interval has elapsed.

```perl
my ( $nodes, $peers, $data ) = $dht->tick( 0.1 );
```

## `ping( $addr, $port )`

Sends a `ping` query.

```
$dht->ping( 'router.bittorrent.com', 6881 );
```

## `find_node_remote( $target_id, $addr, $port )`

Sends a `find_node` query.

```
$dht->find_node_remote( $target_id, '1.2.3.4', 6881 );
```

## `get_peers( $info_hash, $addr, $port )`

Sends a `get_peers` query.

```
$dht->get_peers( $info_hash, '1.2.3.4', 6881 );
```

## `announce_infohash( $info_hash, $port )`

Finds nodes closest to the given infohash and announces that the local node is downloading/seeding on the specified
port. This is a high-level method that combines multiple `get_peers` and `announce_peer` calls.

```
$dht->announce_infohash( $info_hash, 6881 );
```

## `find_peers( $info_hash )`

Queries nodes in the local routing table closest to the infohash. Note that this is a single-step (one-hop) lookup. For
a full iterative Kademlia search, see the `eg/full_search.pl` example in the distribution.

```
$dht->find_peers( $info_hash );
```

## `scrape( $info_hash )`

Queries closest nodes for swarm statistics (BEP 33). This is also a single-step lookup.

```
$dht->scrape( $info_hash );
```

## `sample( $target_id )`

Queries closest nodes for infohash samples (BEP 51). Single-step lookup.

```
$dht->sample( $target_id );
```

## `announce_peer( $info_hash, $token, $announce_port, $addr, $port, [$seed] )`

Announces your presence to a remote node. Requires a token obtained from a previous `get_peers` call to that node.

```
$dht->announce_peer( $hash, $token, 6881, '1.2.3.4', 6881 );
```

## `get_remote( $target, $addr, $port )`

Retrieves data (BEP 44) from a specific node.

```
$dht->get_remote( $target_hash, '1.2.3.4', 6881 );
```

## `put_remote( \%args, $addr, $port )`

Stores data (BEP 44) on a specific node.

```perl
# Immutable
$dht->put_remote( { v => 'data', token => $t }, '1.2.3.4', 6881 );

# Mutable
$dht->put_remote({
    v     => 'new data',
    k     => $pubkey,
    sig   => $signature,
    seq   => 2,
    cas   => 1, # Optional: only update if current seq is 1
    token => $t
}, '1.2.3.4', 6881);
```

## `scrape_peers_remote( $info_hash, $addr, $port )`

Directly queries a specific node for swarm statistics.

```
$dht->scrape_peers_remote( $hash, '1.2.3.4', 6881 );
```

## `sample_infohashes_remote( $target_id, $addr, $port )`

Directly queries a specific node for infohash samples.

```
$dht->sample_infohashes_remote( $target, '1.2.3.4', 6881 );
```

## `routing_table_stats( )`

Returns a hash reference containing the count of nodes in each bucket for both IPv4 and IPv6 tables.

```perl
my $stats = $dht->routing_table_stats( );
printf "Bucket 0 has %d nodes\n", $stats->{v4}[0]{count};
```

## `export_state( )`

Returns a hash representation of the current routing table, peer storage, and data storage.

```perl
my $state = $dht->export_state( );
```

## `import_state( $state )`

Restores the DHT state from a hash generated by `export_state()`.

```
$dht->import_state( $state );
```

## `set_node_id( $new_id )`

Updates the local node ID and refreshes the routing tables.

```
$dht->set_node_id( $new_id );
```

## `external_ip( )`

Returns the current external IP address string as detected by the network (consensus of 5+ nodes).

```perl
if ( my $ip = $dht->external_ip ) {
    say "Network sees us as: $ip";
}
```

## `on( $event, $cb )`

Registers an event handler.

```perl
$dht->on( external_ip_detected => sub ( $ip ) {
    say "New IP: $ip";
});
```

## `run( )`

Blocking loop for simple standalone usage.

```
$dht->run( );
```

## `handle_incoming( [$data, $sender] )`

Processes a packet. Can be called with raw data for custom I/O.

```perl
my ( $nodes, $peers, $data ) = $dht->handle_incoming( $raw_data, $sender_sockaddr );
```

# Event Loop Integration

This module is designed to be protocol-agnostic regarding the event loop.

## Using with IO::Select (Default)

Simply call `tick( $timeout )` in your own loop.

## Using with IO::Async

```perl
my $handle = IO::Async::Handle->new(
    handle => $dht->socket,
    on_read_ready => sub {
        my ($nodes, $peers) = $dht->handle_incoming( );
        # ...
    },
);
$loop->add( $handle );
```

# Supported BEPs

This module implements the following BitTorrent Enhancement Proposals (BEPs):

## BEP 5: Mainline DHT Protocol

The core protocol implementation. It allows for decentralized peer discovery without a tracker.

## BEP 32: IPv6 Extensions

Adds support for IPv6 nodes and peers. Can be toggled via the `bep32` constructor argument.

## BEP 33: DHT Scrapes

Allows querying for the number of seeders and leechers for a specific infohash. Can be toggled via the `bep33`
constructor argument.

## BEP 42: DHT Security Extensions

Implements node ID validation to mitigate specific attacks. Can be toggled via the `bep42` constructor argument. When
enabled, the node will automatically rotate its `node_id` if a consensus regarding a new external IP address is
reached.

## BEP 43: Read-only DHT Nodes

Allows the node to participate in the DHT without being added to other nodes' routing tables. Useful for mobile devices
or low-bandwidth clients. Set the `read_only` constructor argument to a true value.

## BEP 44: Storing Arbitrary Data

Enables `get` and `put` operations for storing immutable and mutable data items in the DHT. Can be explicitly
disabled via the `bep44` constructor argument.

Requests are tracked using internal Transaction IDs (TIDs) to ensure that tokens received from `get` queries are
correctly matched to their intended targets during subsequent `put` operations.

The node strictly enforces BEP 44 security requirements:

- Signatures must be valid and follow the bencoded alphabetical field order.
- Sequence numbers must strictly increase for updates.
- CAS (Compare-and-Swap) is supported to prevent race conditions during concurrent updates.

In order to handle mutable data, [Crypt::PK::Ed25519](https://metacpan.org/pod/Crypt%3A%3APK%3A%3AEd25519) or [Crypt::Perl::Ed25519::PublicKey](https://metacpan.org/pod/Crypt%3A%3APerl%3A%3AEd25519%3A%3APublicKey) must be installed.

## BEP 51: Infohash Indexing

Adds the `sample_infohashes` RPC to allow indexing of the DHT's content. Supported and enabled by default.

# SECURITY

This module aims to protect the node and the network with these following features:

- BEP 42 (Node ID Validation) mitigates Sybil attacks and routing table poisoning.
- Peers that attempt to update mutable data with an invalid signature (BEP 44) are automatically blacklisted. All subsequent queries and responses from their IP address will be ignored for the duration of the session.

# SEE ALSO

[Algorithm::Kademlia](https://metacpan.org/pod/Algorithm%3A%3AKademlia), [Net::BitTorrent::Protocol::BEP03::Bencode](https://metacpan.org/pod/Net%3A%3ABitTorrent%3A%3AProtocol%3A%3ABEP03%3A%3ABencode)

[BEP05](https://www.bittorrent.org/beps/bep_0005.html), [BEP20](https://www.bittorrent.org/beps/bep_0020.html),
[BEP32](https://www.bittorrent.org/beps/bep_0032.html), [BEP33](https://www.bittorrent.org/beps/bep_0033.html),
[BEP42](https://www.bittorrent.org/beps/bep_0042.html), [BEP43](https://www.bittorrent.org/beps/bep_0043.html),
[BEP44](https://www.bittorrent.org/beps/bep_0044.html), [BEP51](https://www.bittorrent.org/beps/bep_0051.html).

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2008-2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.
