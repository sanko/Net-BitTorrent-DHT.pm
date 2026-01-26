use v5.40;
use feature 'class';
no warnings 'experimental::class';

class Net::BitTorrent::DHT::Peer {
    field $ip     : param : reader;
    field $port   : param : reader;
    field $family : param : reader;
    method to_string () {"$ip:$port"}
}
class Net::BitTorrent::DHT v2.0.0 {
    use Algorithm::Kademlia;
    use Net::BitTorrent::DHT::Security;
    use Net::BitTorrent::Protocol::BEP03::Bencode qw[bencode bdecode];
    use IO::Socket::IP;
    use Socket
        qw[sockaddr_family pack_sockaddr_in unpack_sockaddr_in inet_aton inet_ntoa AF_INET AF_INET6 pack_sockaddr_in6 unpack_sockaddr_in6 inet_pton inet_ntop getaddrinfo SOCK_DGRAM];
    use IO::Select;
    use Digest::SHA qw[sha1];
    field $node_id_bin : param : reader;
    field $port             : param : reader = 6881;
    field $address          : param  = undef;
    field $want_v4          : param  = 1;
    field $want_v6          : param  = 1;
    field $bep32            : param  = 1;
    field $bep42            : param  = 1;
    field $security         : reader = Net::BitTorrent::DHT::Security->new();
    field $routing_table_v4 : reader = Algorithm::Kademlia::RoutingTable->new( local_id_bin => $node_id_bin, k => 8 );
    field $routing_table_v6 : reader = Algorithm::Kademlia::RoutingTable->new( local_id_bin => $node_id_bin, k => 8 );
    field $peer_storage     : reader = Algorithm::Kademlia::Storage->new( ttl => 7200 );
    field $socket           : param : reader //= IO::Socket::IP->new( LocalAddr => $address, LocalPort => $port, Proto => 'udp', Blocking => 0 );
    field $select //= IO::Select->new($socket);
    field $debug : param : writer = 0;
    field $token_secret           = pack( "N", rand( 2**32 ) ) . pack( "N", rand( 2**32 ) );
    field $token_old_secret       = $token_secret;
    field $last_rotation          = time();
    field @routers
        //= ( [ 'router.bittorrent.com', 6881 ], [ 'router.utorrent.com', 6881 ], [ 'dht.transmissionbt.com', 6881 ], [ 'dht.aelitis.com', 6881 ] );
    ADJUST {
        $socket // die "Could not create UDP socket: $!"
    }
    method routing_table () {$routing_table_v4}    # Backward compatibility

    method export_state () {
        my @nodes_v4;
        for my $bucket ( $routing_table_v4->buckets ) {
            push @nodes_v4, map { { id => $_->{id}, ip => $_->{data}{ip}, port => $_->{data}{port} } } @$bucket;
        }
        my @nodes_v6;
        for my $bucket ( $routing_table_v6->buckets ) {
            push @nodes_v6, map { { id => $_->{id}, ip => $_->{data}{ip}, port => $_->{data}{port} } } @$bucket;
        }
        return { id => $node_id_bin, nodes => \@nodes_v4, nodes6 => \@nodes_v6, peers => $peer_storage->entries, };
    }

    method import_state ($state) {
        $node_id_bin = $state->{id} if defined $state->{id};
        if ( $state->{nodes} ) {
            my @to_import = map { { id => $_->{id}, data => { ip => $_->{ip}, port => $_->{port} } } } $state->{nodes}->@*;
            $routing_table_v4->import_peers( \@to_import );
        }
        if ( $state->{nodes6} ) {
            my @to_import = map { { id => $_->{id}, data => { ip => $_->{ip}, port => $_->{port} } } } $state->{nodes6}->@*;
            $routing_table_v6->import_peers( \@to_import );
        }
        if ( $state->{peers} ) {
            for my ( $hash, $info )( $state->{peers}->%* ) {
                $peer_storage->put( $hash, $info->{value} );
            }
        }
    }

    method _rotate_tokens () {
        if ( time() - $last_rotation > 300 ) {
            $token_old_secret = $token_secret;
            $token_secret     = pack( "N", rand( 2**32 ) ) . pack( "N", rand( 2**32 ) );
            $last_rotation    = time();
        }
    }

    method _generate_token ( $ip, $secret = undef ) {
        $secret //= $token_secret;
        return sha1( $ip . $secret );
    }

    method _verify_token ( $ip, $token ) {
        return 1 if $token eq $self->_generate_token( $ip, $token_secret );
        return 1 if $token eq $self->_generate_token( $ip, $token_old_secret );
        return 0;
    }

    method bootstrap () {
        for my $r (@routers) {
            $self->ping( $r->@* );
            $self->find_node_remote( $node_id_bin, $r->@* );
        }
    }

    method ping ( $addr, $port ) {
        $self->_send( { t => "pn", y => "q", q => "ping", a => { id => $node_id_bin } }, $addr, $port );
    }

    method find_node_remote ( $target_id, $addr, $port ) {
        $self->_send( { t => 'fn', y => 'q', q => 'find_node', a => { id => $node_id_bin, target => $target_id } }, $addr, $port );
    }

    method get_peers ( $info_hash, $addr, $port ) {
        $self->_send( { t => 'gp', y => 'q', q => 'get_peers', a => { id => $node_id_bin, info_hash => $info_hash } }, $addr, $port );
    }

    method announce_peer ( $info_hash, $token, $announce_port, $addr, $port ) {
        my $msg = {
            t => 'ap',
            y => 'q',
            q => 'announce_peer',
            a => { id => $node_id_bin, info_hash => $info_hash, port => $announce_port, token => $token, }
        };
        $self->_send( $msg, $addr, $port );
    }

    method tick ( $timeout = 0 ) {
        $self->_rotate_tokens();
        if ( $select->can_read($timeout) ) {
            return $self->handle_incoming();
        }
        return ( [], [] );
    }

    method handle_incoming () {
        my $sender = $socket->recv( my $data, 4096 );
        return ( [], [] ) unless defined $data && length $data;
        if ($debug) {
            my ( $p, $i ) = $self->_unpack_address($sender);
            say "[DEBUG] Incoming " . length($data) . " bytes from $i:$p";
        }
        my $msg = eval { bdecode($data) };
        return ( [], [] ) if $@ || ref($msg) ne 'HASH';
        my ( $port, $ip ) = $self->_unpack_address($sender);
        return ( [], [] ) unless $ip;
        if ( ( $msg->{y} // '' ) eq 'q' ) {
            my $node = $self->_handle_query( $msg, $sender, $ip, $port );

            # Return flat format
            return ( $node ? [$node] : [], [] );
        }
        elsif ( $msg->{y} eq 'r' ) {
            return $self->_handle_response( $msg, $sender, $ip, $port );
        }
        return ( [], [] );
    }

    method _unpack_address ($sockaddr) {
        my $family = eval { sockaddr_family($sockaddr) } // return ();
        if ( $family == AF_INET ) {
            my ( $port, $ip_bin ) = unpack_sockaddr_in($sockaddr);
            return ( $port, inet_ntoa($ip_bin) );
        }
        elsif ( $family == AF_INET6 ) {
            my ( $port, $ip_bin, $scope, $flow ) = unpack_sockaddr_in6($sockaddr);
            return ( $port, inet_ntop( AF_INET6, $ip_bin ) );
        }
        return ();
    }

    method _handle_query ( $msg, $sender, $ip, $port ) {
        my $q  = $msg->{q} // return;
        my $a  = $msg->{a} // return;
        my $id = $a->{id}  // return;
        if ( $bep42 && !$security->validate_node_id( $id, $ip ) ) {

            # BEP 42: Reject nodes with invalid IDs
            return;
        }
        my $table = ( $ip =~ /:/ ) ? $routing_table_v6 : $routing_table_v4;
        my $stale = $table->add_peer( $id, { ip => $ip, port => $port } );
        if ($stale) {
            $self->ping( $stale->{data}{ip}, $stale->{data}{port} );
        }
        my $res = { t => $msg->{t}, y => 'r', r => { id => $node_id_bin } };
        if    ( $q eq 'ping' ) { }
        elsif ( $q eq 'find_node' ) {
            my @closest;
            push @closest, $routing_table_v4->find_closest( $a->{target} ) if $want_v4;
            push @closest, $routing_table_v6->find_closest( $a->{target} ) if $want_v6 && $bep32;
            my ( $v4, $v6 ) = $self->_pack_nodes( \@closest );
            $res->{r}{nodes}  = $v4 if $v4 && $want_v4;
            $res->{r}{nodes6} = $v6 if $v6 && $want_v6 && $bep32;
        }
        elsif ( $q eq 'get_peers' ) {
            my $info_hash = $a->{info_hash};
            $res->{r}{token} = $self->_generate_token($ip);
            my $peers = $peer_storage->get($info_hash);
            if ( $peers && @$peers ) {
                my @filtered = grep { ( $_->{ip} =~ /:/ ) ? $want_v6 : $want_v4 } @$peers;
                $res->{r}{values} = $self->_pack_peers_raw( \@filtered );
            }
            else {
                my @closest;
                push @closest, $routing_table_v4->find_closest($info_hash) if $want_v4;
                push @closest, $routing_table_v6->find_closest($info_hash) if $want_v6 && $bep32;
                my ( $v4, $v6 ) = $self->_pack_nodes( \@closest );
                $res->{r}{nodes}  = $v4 if $v4 && $want_v4;
                $res->{r}{nodes6} = $v6 if $v6 && $want_v6 && $bep32;
            }
        }
        elsif ( $q eq 'announce_peer' ) {
            my $info_hash = $a->{info_hash};
            if ( $self->_verify_token( $ip, $a->{token} ) ) {
                my $peers    = $peer_storage->get($info_hash) // [];
                my $new_peer = { ip => $ip, port => ( $a->{implied_port} ? $port : $a->{port} ) };
                @$peers = grep { $_->{ip} ne $ip } @$peers;
                push @$peers, $new_peer;
                $peer_storage->put( $info_hash, $peers );
            }
        }
        $self->_send_raw( bencode($res), $sender );
        return { id => $id, ip => $ip, port => $port };
    }

    method _handle_response ( $msg, $sender, $ip, $port ) {
        my $r = $msg->{r};
        return ( [], [] ) unless $r && $r->{id};
        if ( $bep42 && !$security->validate_node_id( $r->{id}, $ip ) ) {
            return ( [], [] );
        }
        my $table = ( $ip =~ /:/ ) ? $routing_table_v6 : $routing_table_v4;
        my $stale = $table->add_peer( $r->{id}, { ip => $ip, port => $port } );
        if ($stale) {
            $self->ping( $stale->{data}{ip}, $stale->{data}{port} );
        }
        my $peers = [];
        if ( $r->{values} ) {
            $peers = $self->_unpack_peers( $r->{values} );
        }
        my @learned;
        if ( $r->{nodes} ) {
            push @learned, $self->_unpack_nodes( $r->{nodes}, AF_INET )->@*;
        }
        if ( $r->{nodes6} ) {
            push @learned, $self->_unpack_nodes( $r->{nodes6}, AF_INET6 )->@*;
        }
        for my $node (@learned) {
            if ( $bep42 && !$security->validate_node_id( $node->{id}, $node->{ip} ) ) {
                next;
            }
            my $ntable = ( $node->{ip} =~ /:/ ) ? $routing_table_v6 : $routing_table_v4;
            $ntable->add_peer( $node->{id}, { ip => $node->{ip}, port => $node->{port} } );
        }

        # Always include the responding node itself
        push @learned, { id => $r->{id}, ip => $ip, port => $port };
        return ( \@learned, $peers );
    }

    method _send ( $msg, $addr, $port ) {
        my ( $err, @res ) = getaddrinfo( $addr, $port, { socktype => SOCK_DGRAM } );
        return if $err || !@res;
        for my $res (@res) {
            my $family = sockaddr_family( $res->{addr} );
            if ( $family == AF_INET && $want_v4 ) {
                $self->_send_raw( bencode($msg), $res->{addr} );
            }
            elsif ( $family == AF_INET6 && $want_v6 ) {
                $self->_send_raw( bencode($msg), $res->{addr} );
            }
        }
    }

    method _send_raw ( $data, $dest ) {
        if ($debug) {
            my ( $p, $i ) = $self->_unpack_address($dest);
            say "[DEBUG] Sending " . length($data) . " bytes to $i:$p";
        }
        $socket->send( $data, 0, $dest );
    }

    method _pack_nodes ($peers) {
        my $v4 = "";
        my $v6 = "";
        for my $p (@$peers) {
            my $ip   = $p->{data}{ip};
            my $port = $p->{data}{port} // 0;
            if ( $ip =~ /:/ ) {
                next unless $want_v6;
                my $ip_bin = inet_pton( AF_INET6, $ip );
                $v6 .= $p->{id} . $ip_bin . pack( "n", $port ) if $ip_bin;
            }
            else {
                next unless $want_v4;
                my $ip_bin = inet_aton($ip);
                $v4 .= $p->{id} . $ip_bin . pack( "n", $port ) if $ip_bin;
            }
        }
        return ( $v4, $v6 );
    }

    method _unpack_nodes ( $blob, $family = AF_INET ) {
        my @nodes;
        my $stride = ( $family == AF_INET ) ? 26 : 38;
        my $ip_len = ( $family == AF_INET ) ? 4  : 16;
        while ( length($blob) >= $stride ) {
            my $chunk  = substr( $blob,  0,  $stride, "" );
            my $id     = substr( $chunk, 0,  20 );
            my $ip_bin = substr( $chunk, 20, $ip_len );
            my $port   = unpack( "n", substr( $chunk, 20 + $ip_len, 2 ) );
            my $ip     = ( $family == AF_INET ) ? inet_ntoa($ip_bin) : inet_ntop( AF_INET6, $ip_bin );
            push @nodes, { id => $id, ip => $ip, port => $port };
        }
        return \@nodes;
    }

    method _unpack_peers ($list) {
        my @peers;
        my @blobs = ( ref($list) eq 'ARRAY' ) ? @$list : ($list);
        for my $blob (@blobs) {
            while ( length($blob) >= 6 ) {
                if ( length($blob) % 18 == 0 ) {
                    my $chunk = substr( $blob, 0, 18, "" );
                    my ( $ip_bin, $port ) = unpack( "a16 n", $chunk );
                    push @peers, Net::BitTorrent::DHT::Peer->new( ip => inet_ntop( AF_INET6, $ip_bin ), port => $port, family => 6 ) if $want_v6;
                }
                else {
                    my $chunk = substr( $blob, 0, 6, "" );
                    my ( $ip_bin, $port ) = unpack( "a4 n", $chunk );
                    push @peers, Net::BitTorrent::DHT::Peer->new( ip => inet_ntoa($ip_bin), port => $port, family => 4 ) if $want_v4;
                }
            }
        }
        return \@peers;
    }

    method _pack_peers_raw ($peers) {
        return [
            map {
                ( $_->{ip} =~ /:/ ) ? ( inet_pton( AF_INET6, $_->{ip} ) . pack( "n", $_->{port} ) ) :
                    ( inet_aton( $_->{ip} ) . pack( "n", $_->{port} ) )
            } @$peers
        ];
    }

    method run () {
        $self->bootstrap();
        while (1) {
            $self->tick(1);
        }
    }
};
1;
