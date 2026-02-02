# 'mai_FORM_TITLE' => 'E-mail settings',
'mai_E-Mail' => 'Email',
# 'mai_SUCCESS' => 'The new e-mail settings have been saved.',
'mai_NEVER' => 'not at all',
'mai_EVERY5MIN' => 'Every 5 minutes',
'mai_EVERY15MIN' => 'Every 15 minutes',
'mai_EVERY30MIN' => 'Every 30 minutes',
'mai_EVERYHOUR' => 'Every hour',
'mai_EVERY2HRS' => 'Every 2 hours',
'mai_STANDARD' => 'Standard (SMTP)',
'mai_ETRN' => 'ETRN (SMTP with client request)',
'mai_DEFAULT' => 'Default',
'mai_SPECIFY_BELOW' => 'Specify below',
'mai_MULTIDROP' => 'multi-drop',
'mai_LABEL_MODE' => 'E-mail retrieval mode',
'mai_DESC_MODE' => 'The e-mail retrieval mode can be set to
standard (for dedicated Internet connections), ETRN (recommended
for dialup connections), or multi-drop (for dialup connections if
ETRN is not supported by your Internet provider). Note that
multi-drop mode is the only option available when the server is
configured in private server and gateway mode.',
'mai_LABEL_DELEGATE' => 'IP Address of internal mail server',
'mai_TITLE_DELEGATE' => 'Delegate mail servers',
'mai_DESC_DELEGATE' => 'Your server includes a complete, full-featured e-mail server. However,
if for some reason you wish to delegate e-mail processing to
another system, specify the IP address of the delegate system
here. For normal operation, leave this field blank.',
'mai_LABEL_SECONDARY' => 'Secondary mail server',
'mai_TITLE_SECONDARY' => 'ETRN or multi-drop settings',
'mai_DESC_SECONDARY' => 'For ETRN or multi-drop, specify the hostname or IP address of your
secondary mail server. (If using the standard e-mail setup, this
field can be left blank.)',
'mai_DESC_FETCH_PERIOD' => 'For ETRN or multi-drop, you can control how frequently this server
contacts your secondary e-mail server to fetch e-mail. More
frequent connections mean that you receive your e-mail more
quickly, but also cause Internet requests to be sent more often,
possibly increasing your phone and Internet charges.',
'mai_LABEL_FETCH_PERIOD' => 'During office hours (8:00 AM to 6:00 PM) on weekdays',
'mai_LABEL_FETCH_PERIOD_NIGHTS' => 'Outside office hours (6:00 PM to 8:00 AM) on weekdays',
'mai_LABEL_FETCH_PERIOD_WEEKENDS' => 'During the weekend',
# 'mai_DESC_POP_ACCOUNT' => 'For multi-drop e-mail, specify the POP user account and password.
# (If using standard or ETRN e-mail, these fields can be blank.)
# Also, for multi-drop, you can either use the default mail sorting
# method, or you can specify a particular message header to use for
# mail sorting.',
'mai_LABEL_POP_PASS' => 'POP user password (for multi-drop)',
'mai_LABEL_POP_ACCOUNT' => 'POP user account (for multi-drop)',
'mai_LABEL_SORT_METHOD' => 'Select sort method (for multi-drop)',
'mai_LABEL_SORT_HEADER' => 'Select sort header (for multi-drop)',
# 'mai_LABEL_FETCH_PROTO' => 'Protocol (for multi-drop)',
# 'mai_LABEL_FETCH_SECURE' => 'Tunnel over SSL (for multi-drop)',
# 'mai_AUTO' => 'Automatic',
# 'mai_ENABLED_BOTH' => 'Allow both HTTP and HTTPS',
'mai_ENABLED_SECURE_ONLY' => 'Allow HTTPS (secure)',
'mai_ONLY_LOCAL_NETWORK_SSL' => 'Allow HTTPS (secure) from local networks',
'mai_INSECURE_POP3' => 'Allow both POP3 and POP3S',
# 'mai_ALLOW_PRIVATE' => 'Allow private',
'mai_SECURE_POP3' => 'Allow private and public (secure POP3S)',
'mai_INSECURE_IMAP' => 'Allow both IMAP and IMAPS',
'mai_SECURE_IMAP' => 'Allow private and public (secure IMAPS)',
# 'mai_INSECURE_SMTP' => 'Allow both SMTP and SSMTP',
'mai_SECURE_SMTP' => 'Allow SSMTP (secure)',
'mai_LABEL_POP_ACCESS_CONTROL' => 'POP3 server access',
'mai_LABEL_IMAP_ACCESS_CONTROL' => 'IMAP server access',
# 'mai_LABEL_SMTP_AUTH_CONTROL' => 'SMTP authentication',
'mai_FORWARD_TO_ADMIN' => 'Send to administrator',
'mai_FORWARD_TO' => 'Send to',
'mai_RETURN_TO_SENDER' => 'Reject',
'mai_LABEL_UNKNOWN' => 'E-mail to unknown users',
'mai_TITLE_UNKNOWN' => 'Unknown Users',
'mai_DESC_UNKNOWN' => 'Selecting Reject (recommended setting) will configure the server to only
accept mail for valid email addresses (for example users, groups, pseudonyms).
Mail for other addresses will be rejected.',
'mai_LABEL_SMARTHOST' => 'Address of Internet provider\'s mail server',
'mai_TITLE_SMARTHOST' => 'SMTP server',
'mai_DESC_SMARTHOST' => 'The server can deliver outgoing messages directly to their
destination (recommended in most cases) or can deliver them via
your Internet provider\'s SMTP server (recommended if you have an
unreliable Internet connection or are using a residential Internet
service). If using your Internet provider\'s SMTP server, specify
its hostname or IP address below. Otherwise leave this field blank.',
'mai_INVALID_SMARTHOST' => 'The smarthost name you entered is not a valid internet domain name and is not blank',
'mai_INVALID_DELEGATE' => 'The delegate host name you entered is not a valid IP Address and is not blank',
'mai_DESC_POP_ACCESS_CONTROL' => 'You can control POP3 server access. The setting \'Allow access
only from local networks\' allows POP3 access only from your
local network(s). The POP3S setting can be used to provide
encrypted external access to your POP3 server. We recommend
leaving this setting \'Allow access only from local networks\'
unless you have a specific reason to do otherwise.',
'mai_DESC_IMAP_ACCESS_CONTROL' => 'You can control IMAP server access. The setting \'Allow access
only from local networks\' allows IMAP access only from your
local network(s). The IMAPS setting can be used to provide
encrypted external access to your IMAP server. We recommend
leaving this setting \'Allow access only from local networks\'
unless you have a specific reason to do otherwise.',
'mai_DESC_SMTP_AUTH_CONTROL' => 'You can provide authenticated access to your SMTP server, or 
set it to Disabled.
The SSMTP setting requires <b>all</b> users to use SSL/TLS 
authentication. The SMTP and SSMTP option additionally allows 
STARTTLS to be used to ensure secure authentication.',
'mai_DESC_WEBMAIL' => 'You can enable or disable webmail on this system. Webmail allows
users to access their mail through a regular web browser by
pointing the browser to https://[_1]/webmail,and 
 logging in to their account.',
'mai_LABEL_WEBMAIL' => 'Webmail access',
'mai_LABEL_BLOCK_EXECUTABLE_CONTENT' => 'Executable content blocking',
'mai_LABEL_CONTENT_TO_BLOCK' => 'Content to block',
'mai_DESC_BLOCK_EXECUTABLE_CONTENT' => 'You can block executable content in e-mail attachments
by highlighting the executable attachment types you wish to
block. E-mail containing these attachment types will 
be automatically returned to the sender.',
# 'mai_UNACCEPTABLE_CHARS' => 'This field requires a valid e-mail address, which must include
# the @ symbol and a domain name.',
# 'mai_DESC_STATE_ACCESS' => 'E-mail access',
'mai_DESC_STATE_ACCESS_BUTTON' => 'Change e-mail access settings',
# 'mai_DESC_STATE_RECEPTION' => 'E-mail reception',
'mai_DESC_STATE_RECEPTION_BUTTON' => 'Change e-mail reception settings',
# 'mai_DESC_STATE_DELIVERY' => 'E-mail delivery',
'mai_DESC_STATE_DELIVERY_BUTTON' => 'Change e-mail delivery settings',
'mai_DESC_STATE_FILTERING_BUTTON' => 'Change e-mail filtering settings',
'mai_LABEL_VIRUS_SCAN' => 'Virus scanning',
'mai_DESC_VIRUS_SCAN' => 'You can scan incoming and outgoing e-mail for viruses. If scanning is enabled and a virus is detected, the e-mail will be rejected and returned to the
sender.',
'mai_LABEL_SPAM_SCAN' => 'Spam filtering',
'mai_DESC_SPAM_SCAN' => 'You can scan e-mail for spam. If Spam filtering is
enabled, an X-Spam-Status: header is added to each
message, which can be used for filtering spam.
You can adjust the sensitivity of the Spam detection
process from the default of medium. For fine-grained
control, you can set the Spam sensitivity to Custom
and then choose a custom tagging level, and 
optionally a level at which to reject the message.',
'mai_LABEL_SPAM_SUBJECT' => 'SPAM subject prefix',
'mai_DESC_SPAM_SUBJECT' => 'You can enable to add a tag to the subject of each
message that is classified as SPAM.
The value for this tag can be defined below.',
'mai_LABEL_SPAM_SENSITIVITY' => 'Spam sensitivity',
'mai_LABEL_SPAM_TAGLEVEL' => 'Custom spam tagging level',
'mai_LABEL_SPAM_REJECTLEVEL' => 'Custom spam rejection level',
'mai_LABEL_SPAM_SUBJECTTAG' => 'Modify subject of spam messages',
'mai_LABEL_SORTSPAM' => 'Sort spam into junkmail folder',
'mai_VERYHIGH' => 'Very high',
'mai_HIGH' => 'High',
'mai_MEDIUM' => 'Medium',
'mai_LOW' => 'Low',
'mai_VERYLOW' => 'Very low',
'mai_CUSTOM' => 'Custom',
'mai_LABEL_SMARTHOST_SMTPAUTH_STATUS' => 'SMTP Authentication for Internet provider',
'mai_LABEL_SMARTHOST_SMTPAUTH_USERID' => 'Mail server user id',
'mai_LABEL_SMARTHOST_SMTPAUTH_PASSWD' => 'Mail server password',
'mai_VALIDATION_SMTPAUTH_NONBLANK' => 'The user id and password fields cannot be left blank if SMTP Authentication is
enabled.',
'mai_ACC_panel_action_was_successful' => 'Email access settings saved sucessfully',
'mai_DEL_panel_action_was_successful' => 'Email delivery settings saved sucessfully',
'mai_FIL_panel_action_was_successful' => 'Email filtering settings saved sucessfully',
'mai_REC_panel_action_was_successful' => 'Email receive settings saved sucessfully',

'mai_SMTP_port_authenticate' => 'Smtp port %u allow client to authenticate:',
# 'mai_SMTP_port_(25)' => 'Smtp port (25) main purpose is to receive emails from another server, starttls is always offered, but auth if offered is only if starttls is also used by client.',
'mai_SMTP_Submission' => 'Smtp submission port (587) will require starttls, then authenticate to send.',
# 'mai_SMTPS_port_(465)' => 'Smtps port (465) will require implicit ssl/tls then authenticate to send.',
# 'mai_SMTPS_SSL/TLS' => 'Smtps ssl/tls auth: port %u status:',
'mai_Submission_port' => 'Submission port %u status:',
'mai_LABEL_SMARTHOST_SMTPAUTH_PEERPORT' => 'Peer Port of Internet provider\'s mail server',
'mai_DESC_PEERPORT' => 'Usually 25, 587 or 467. If empty will assume 25.',
'mai_FRONT_panel_action_was_successful' => 'Front panel action was successful',
