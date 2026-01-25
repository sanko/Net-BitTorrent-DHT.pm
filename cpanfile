requires 'perl', '5.040000';
requires 'Net::Kademlia', '0';
requires 'Net::BitTorrent::Protocol::BEP03::Bencode', '0';
requires 'IO::Socket::INET', '0';
requires 'IO::Select', '0';
requires 'Socket', '0';
on 'test' => sub { requires 'Test2::V0', '0'; };

