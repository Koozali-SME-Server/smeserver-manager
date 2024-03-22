#! /bin/bash

#> unshift secrets values
#> refresh Routes base
#> refresh Navigation menu bases
### refresh Rest password base
#> expand smanager.conf et reload service
### smanager activity test

SMANAGER_DIR='/usr/share/smanager'

# unshift secrets value
$SMANAGER_DIR/script/secrets.pl

# refresh routes database
$SMANAGER_DIR/script/routes.pl

# refresh Navigation menu database
#$SMANAGER_DIR/script/navigation.pl

# smanager config files and databases
/sbin/e-smith/expand-template $SMANAGER_DIR/conf/srvmngr.conf
/sbin/e-smith/signal-event smanager-refresh

exit 0
