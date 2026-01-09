'prx_TITLE' => 'Proxy settings',
'prx_FIRST_PAGE_DESCRIPTION' => 'This page allows configuration of the server\'s 
proxy settings.
The server includes a transparent proxy and cache for 
HTTP traffic. This is enabled by default, but not enforced 
if the server is in &quot;serveronly&quot; mode. 
If this server is acting as an e-mail server, connections 
from local network clients to external SMTP servers 
will default to being redirected to the local e-mail server.',
'prx_HTTP_PROXY_STATUS_DESCRIPTION' => 'The server\'s HTTP proxy works to reduce overall uplink usage by
caching recently-visited pages. It is transparent to web browsers
using this server as their gateway. Enable or disable this proxy
with the following toggle.',
'prx_HTTP_PROXY_STATUS_LABEL' => 'HTTP proxy status',
'prx_SMTP_PROXY_STATUS_DESCRIPTION' => 'The server\'s transparent SMTP proxy works to reduce virus traffic 
from infected client hosts by forcing all outgoing SMTP traffic 
through this server if set to "enabled". 
If you wish to use an alternate SMTP server, and this server is 
your gateway to it, set this proxy to "disabled". Setting the 
proxy to "blocked" prevents all SMTP traffic to other servers, 
this is the default. The proxy only intercepts/blocks normal smtp 
(port 25) traffic.',
'prx_SMTP_PROXY_STATUS_LABEL' => 'SMTP proxy status',
'prx_ERR_PROXY_UPDATE_FAILED' => 'ERROR: The proxy-update event returned an error.',
'prx_ERR_NO_SQUID_REC' => 'ERROR: There is no squid record in the configuration database.',
'prx_SUCCESS' => 'The new proxy settings were applied successfully.',
'prx_BLOCKED' => 'Blocked',
'Proxy settings' => 'Proxy settings',
'prx_Proxy' => 'Proxy',