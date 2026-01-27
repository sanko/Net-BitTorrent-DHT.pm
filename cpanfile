requires 'Algorithm::Kademlia';
requires 'Crypt::Perl::Ed25519::PublicKey';
requires 'IO::Select';
requires 'IO::Socket::INET';
requires 'Net::BitTorrent::Protocol::BEP03::Bencode';
requires 'Socket';
requires 'perl', 'v5.42.0';
recommends 'IO::Async';
on configure => sub {
    requires 'Module::Build::Tiny';
    requires 'perl', 'v5.42.0';
};
on build => sub {
    requires 'Module::Build::Tiny';
};
on test => sub {
    requires 'Test2::V0';
};
