use v5.40;
use feature 'class';
no warnings 'experimental::class';

class Net::BitTorrent::DHT;

use Net::Kademlia::RoutingTable;
use Net::BitTorrent::Protocol::BEP03::Bencode qw(bencode bdecode);
use IO::Socket::INET;
use Socket qw(pack_sockaddr_in inet_aton);
use IO::Select;

our $VERSION = '0.0.1';

field $node_id_bin :param;
field $port :param = 6881;
field $routing_table :reader;
field $socket;
field $select;
field %tokens; # token -> timestamp

ADJUST {
    $routing_table = Net::Kademlia::RoutingTable->new(
        local_id_bin => $node_id_bin,
        k => 8 # BitTorrent uses k=8
    );

    $socket = IO::Socket::INET->new(
        LocalPort => $port,
        Proto     => 'udp',
        Blocking  => 0,
    ) or die "Could not create UDP socket: $!";

    $select = IO::Select->new($socket);
}

method bootstrap () {
    say "[DHT] Bootstrapping via router.bittorrent.com...";
    $self->ping('router.bittorrent.com', 6881);
    $self->ping('dht.transmissionbt.com', 6881);

    # Also perform a find_node on ourselves to fill buckets
    $self->find_node_remote($node_id_bin, 'router.bittorrent.com', 6881);
}

method ping ($addr, $port) {
    my $msg = {
        t => "pn",
        y => "q",
        q => "ping",
        a => { id => $node_id_bin }
    };
    $self->_send($msg, $addr, $port);
}

method find_node_remote ($target_id, $addr, $port) {
    my $msg = {
        t => "fn",
        y => "q",
        q => "find_node",
        a => { id => $node_id_bin, target => $target_id }
    };
    $self->_send($msg, $addr, $port);
}

method get_peers ($info_hash, $addr, $port) {
    my $msg = {
        t => "gp",
        y => "q",
        q => "get_peers",
        a => { id => $node_id_bin, info_hash => $info_hash }
    };
    $self->_send($msg, $addr, $port);
}

method run () {
    say "[DHT] Node running on port $port. ID: " . unpack("H*", $node_id_bin);
    $self->bootstrap();

    while (1) {
        if ($select->can_read(1)) {
            $self->handle_incoming();
        }
        # Periodically refresh buckets or re-bootstrap if empty
    }
}

method handle_incoming () {

    my $sender = $socket->recv(my $data, 4096);

    return [] unless $data;



    my $msg;

    eval { $msg = bdecode($data); };

    if ($@) { return []; }

    return [] unless $msg && ref($msg) eq 'HASH';



    my ($port, $ip_bin) = unpack_sockaddr_in($sender);

    my $ip = inet_ntoa($ip_bin);



    if ($msg->{y} eq 'q') {

        $self->_handle_query($msg, $sender);

        return [];

    } elsif ($msg->{y} eq 'r') {

        return $self->_handle_response($msg, $sender);

    }

    return [];

}





method _handle_query ($msg, $sender) {

    my $q = $msg->{q};

    my $id = $msg->{a}{id};



    my ($port, $ip_bin) = unpack_sockaddr_in($sender);

    $routing_table->add_peer($id, { ip => inet_ntoa($ip_bin), port => $port });



    my $res = { t => $msg->{t}, y => 'r', r => { id => $node_id_bin } };



    if ($q eq 'ping') {

        # Reply already set

    } elsif ($q eq 'find_node') {

        my $target = $msg->{a}{target};

        my $closest = $routing_table->find_closest($target);

        $res->{r}{nodes} = $self->_pack_nodes($closest);

    } elsif ($q eq 'get_peers') {

        my $info_hash = $msg->{a}{info_hash};

        $res->{r}{token} = $self->_generate_token($sender);

        my $closest = $routing_table->find_closest($info_hash);

        $res->{r}{nodes} = $self->_pack_nodes($closest);

    }



    $self->_send_raw(bencode($res), $sender);

}



method _handle_response ($msg, $sender) {



    my $r = $msg->{r};



    return [] unless $r && $r->{id};







    my ($port, $ip_bin) = unpack_sockaddr_in($sender);



    $routing_table->add_peer($r->{id}, { ip => inet_ntoa($ip_bin), port => $port });







    if ($r->{values}) {



        my $peers = $self->_unpack_peers($r->{values});



        if (@$peers) {



            say "[DHT] SUCCESS: Found " . scalar(@$peers) . " peers for info_hash!";



            foreach my $p (@$peers) {



                say "  [PEER] " . $p->{ip} . ":" . $p->{port};



            }



        }



    }







    my @learned;



    if ($r->{nodes}) {



        @learned = $self->_unpack_nodes($r->{nodes})->@*;



        foreach my $node (@learned) {



            $routing_table->add_peer($node->{id}, { ip => $node->{ip}, port => $node->{port} });



        }



    }



    return \@learned;



}







method _send ($msg, $addr, $port) {

    my $ip_aton = inet_aton($addr);

    return unless $ip_aton;

    my $dest = pack_sockaddr_in($port, $ip_aton);

    $self->_send_raw(bencode($msg), $dest);

}



method _send_raw ($data, $dest) {

    $socket->send($data, 0, $dest);

}



method _pack_nodes ($peers) {

    my $out = "";

    foreach my $p (@$peers) {

        $out .= $p->{id}; # 20 bytes

        my $ip_bin = inet_aton($p->{data}{ip} // '127.0.0.1');

        $out .= $ip_bin . pack("n", $p->{data}{port} // 0);

    }

    return $out;

}



method _unpack_nodes ($blob) {
    my @nodes;
    while (length($blob) >= 26) {
        my $chunk = substr($blob, 0, 26, "");
        my ($id, $ip_bin, $port) = unpack("a20 a4 n", $chunk);
        push @nodes, { id => $id, ip => inet_ntoa($ip_bin), port => $port };
    }
    return \@nodes;
}

method _unpack_peers ($list) {
    my @peers;
    # Sometimes 'values' can be a single string of 6-byte chunks
    # instead of a list of strings.
    if (ref($list) eq 'ARRAY') {
        foreach my $blob (@$list) {
            if (length($blob) == 6) {
                my ($ip_bin, $port) = unpack("a4 n", $blob);
                push @peers, { ip => inet_ntoa($ip_bin), port => $port };
            }
        }
    } else {
        # Treat as compact string
        my $blob = $list;
        while (length($blob) >= 6) {
            my $chunk = substr($blob, 0, 6, "");
            my ($ip_bin, $port) = unpack("a4 n", $chunk);
            push @peers, { ip => inet_ntoa($ip_bin), port => $port };
        }
    }
    return \@peers;
}

method _generate_token ($sender) {
    return "secret_token_" . time(); # Simplified
}

1;

__END__

=pod

=head1 NAME

Net::BitTorrent::DHT - BitTorrent Mainline DHT implementation

=head1 SYNOPSIS

    use Net::BitTorrent::DHT;

    my $dht = Net::BitTorrent::DHT->new(
        node_id_bin => pack("H*", "0123456789abcdef0123456789abcdef01234567"),
        port => 6881
    );

    # Ping a bootstrap node
    $dht->ping('router.bittorrent.com', 6881);

=head1 DESCRIPTION

Implements the BitTorrent DHT protocol (BEP 5) using the generic
L<Net::Kademlia> routing logic and BEP 3 Bencode serialization.

=cut
