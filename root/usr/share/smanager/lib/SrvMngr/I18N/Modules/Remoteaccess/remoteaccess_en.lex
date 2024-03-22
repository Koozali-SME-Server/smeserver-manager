
'rma_FORM_TITLE' => 'Change remote access settings',
'rma_DESCRIPTION' => 'For each of the options below, the private setting allows anyone
from your local network to access your server. The
public setting allows access from anywhere on the Internet. The no
access setting disables access. To understand the security
implications of changing these options from the default settings, you
should read the user\'s guide section on remote access.',
'rma_SUCCESS' => 'The new remote access settings have been saved.',
'rma_NO_ACCESS' => 'No Access',
'rma_PASSWORD_LOGIN_PRIVATE' => 'Accept passwords only from local networks',
'rma_PASSWORD_LOGIN_PUBLIC' => 'Accept passwords from anywhere',
'rma_LABEL_TELNET_ACCESS' => 'Telnet access',
'rma_LABEL_FTP_ACCESS' => 'FTP access',
'rma_LABEL_FTP_LOGIN' => 'FTP password access',
'rma_LABEL_PPTP' => 'Number of PPTP clients',
 'rma_NUMBER_OF_PPTP_CLIENTS_MUST_BE_LESSER_THAN_NUMBER_OF_IP_IN_DHCP_RANGE' => 'The number of pptp clients is greater than the number of reserved IP for DHCP. You should take a smaller number.',
'rma_LABEL_SSH_PORT' => 'TCP Port for secure shell access',
'rma_LABEL_SSH' => 'Secure shell access',
'rma_LABEL_SSH_ADMIN' => 'Allow administrative command line access over secure shell',
'rma_LABEL_SSH_PASSWORD_ACCESS' => 'Allow secure shell access using standard passwords',
'rma_TITLE_SSH' => 'Secure Shell Settings',
'rma_DESC_SSH' => 'You can control Secure Shell access to your server.
The public setting should only be enabled by 
experienced administrators 
for remote problem diagnosis and resolution. 
We recommend leaving this
parameter set to "No Access"
unless you have a specific reason to do otherwise.',
'rma_TITLE_FTP_ACCESS' => 'FTP Settings',
'rma_DESC_FTP_ACCESS' => 'You can also control <b>FTP</b> access to your server. We
recommend leaving this parameter set to \'no access\' unless you
have a specific reason to do otherwise.
<p>
Note: these settings limit access to the server and override other 
settings, including those for individual information bays.</p>',
'rma_DESC_FTP_LOGIN' => 'You can also control authenticated FTP access to information
bays and user accounts. We strongly recommend leaving this
parameter set to private unless you have a specific reason to
do otherwise.
<p>
Note: a secure shell sftp client can also be used to access the
server, if remote access via the secure shell is enabled.
This method of access protects the
passwords and data of the FTP session, whereas standard FTP
provides no protection.</p>',
'rma_TITLE_PPTP' => 'PPTP Settings',
'rma_DESC_PPTP' => 'You can allow PPTP access to your server. 
You should leave this feature disabled by setting the value 
to the number 0 unless you require PPTP access.',
'rma_VALUE_ZERO_OR_POSITIVE' => 'Value must be zero or a positive integer',
'rma_REMOTE_MANAGEMENT' => 'Remote Management',
'rma_VALIDFROM_TITLE' => '[_1]',
'rma_VALIDFROM_DESC' => 'It is possible to allow hosts on remote networks to access the
server manager by entering those networks here. Use a subnet
mask of 255.255.255.255 to limit the access to the specified host.
Any hosts within the specified range will be able to access the
server manager using HTTPS.',
'rma_DESC_VALID_FROM_ENTRIES' => 'To add a new remote management network, 
enter the details below.',
'rma_SUBNET_MASK' => 'Subnet mask',
'rma_NUM_OF_HOSTS' => 'Number of hosts',
'rma_NO_ENTRIES_YET' => 'There are no entries yet',
'rma_INVALID_SUBNET_MASK' => 'Invalid subnet mask',
'rma_ERR_INVALID_PARAMS' => 'Either provide both a network and subnet mask, or leave both
fields blank.',
'rma_ERR_NO_RECORD' => 'Unable to locate httpd-admin record in configuration db',
'Remote access' => 'Remote access',
'rma_LABEL_SERIAL_CONSOLE_ACCESS' => 'Serial console',
'rma_DESC_SERIAL_CONSOLE_ACCESS' => ' <hr class="sectionbar" /><h2>Serial console</h2>
You can allow access to the server console from a terminal
connected to a server serial port.',
'rma_PORT1_ENABLED' => 'Enabled on serial port 1',
'rma_PORT2_ENABLED' => 'Enabled on serial port 2',
'rma_LABEL_PPTP_ACCESS' => 'PPTP default user access',
'rma_TITLE_TELNET_ACCESS' => 'Telnet Settings',
'rma_DESC_TELNET_ACCESS' => 'WARNING:Telnet is currently enabled, but this feature is
no longer supported.Telnet is inherently insecure and should only
be used in circumstances where no practical alternative exists. You
should change option to [_1] and use
secure shell if remote access is
required.Once disabled, telnet will no longer appear on this 
screen. ',
'rma_TITLE_IPSECRW' => 'IPSEC Client (Roadwarrior) Settings',
'rma_DESC_IPSECRW' => 'You can allow IPSEC client access to your server, authenticated by
digital certificates. You should leave this feature disabled by setting the value 
to the number 0 unless you require IPSEC client access.',
'rma_LABEL_IPSECRW_SESS' => 'Number of IPSEC clients',
'rma_DESC_IPSECRW_RESET' => 'If you wish to reset all digital certificates, you
can do so here.<br>Any old certificates will no longer
authenticate against the server, so <b><i>all IPSEC clients will
need to import a new certificate!</i></b>.',
'rma_LABEL_IPSECRW_RESET' => 'Reset digital certificates',
