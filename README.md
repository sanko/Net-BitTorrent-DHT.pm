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

## `new( node_id_bin => ..., [ port => 6881, address => ... ] )`

Constructor. `node_id_bin` must be a 20-byte binary string.

## `bootstrap( )`

Sends `ping` and `find_node` requests to well-known router nodes to populate the initial routing table.

## `tick( [ $timeout ] )`

Processes any pending incoming UDP packets. Returns two array references: `($learned_nodes, $found_peers)`.

## `ping( $addr, $port )`

Sends a `ping` query to the specified node.

## `find_node_remote( $target_id, $addr, $port )`

Sends a `find_node` query for the specified target ID.

## `get_peers( $info_hash, $addr, $port )`

Sends a `get_peers` query for the specified info-hash.

## `announce_peer( $info_hash, $token, $announce_port, $addr, $port )`

Sends an `announce_peer` query. Requires a `token` received from a previous `get_peers` call.

## `run( )`

Enters an infinite loop calling `tick()`.

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
