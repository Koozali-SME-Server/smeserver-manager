#! /bin/env perl

# unshift secrets values
# 3 secrets values (first one for encrypt, all 3 for decrypt)
# new value added each day as first one

use strict;
use warnings;

use esmith::ConfigDB;

sub gen_pwd {
    use MIME::Base64 qw(encode_base64);
    my $p = "not set due to error";
    if ( open( RANDOM, "/dev/urandom" ) ){
        my $buf;
        # 57 bytes is a full line of Base64 coding, and contains
        # 456 bits of randomness - given a perfectly random /dev/random
        if ( read( RANDOM, $buf, 57 ) != 57 ){
            warn("Short read from /dev/random: $!");
        } else {
            $p = encode_base64($buf);
            chomp $p;
        }
        close RANDOM;
    } else {
        warn "Could not open /dev/urandom: $!";
    }
    return $p;
}

my $cdb = esmith::ConfigDB->open() || die "Couldn't open config db";

my $pwds = $cdb->get_prop('smanager','Secrets');

if ( $pwds ){
    my @secrets = split /,/, $pwds;
    my $newpwd = gen_pwd();
    if ( $newpwd ) {
        $secrets[2] = $secrets[1] if ( $secrets[1] );
	$secrets[1] = $secrets[0];
	$secrets[0] = $newpwd;
	my $secret = join ',', @secrets;
        $cdb->get('smanager')->set_prop('Secrets', $secret);
	#print("Secret values unshifted\n");
    } else {
	print("Secret generation error\n");
    }
} else {
    print("Error while unshifting secrets values\n");
}

exit 0
