use v5.40;
use lib '../lib';
use Net::BitTorrent::DHT;
$|++;

# Generate a random 20-byte Node ID
my $id  = pack( "C*", map { int( rand(256) ) } 1 .. 20 );
my $dht = Net::BitTorrent::DHT->new( node_id_bin => $id, port => 6881 + int( rand(100) ) );

# This will enter an infinite loop
$dht->start_loop();
