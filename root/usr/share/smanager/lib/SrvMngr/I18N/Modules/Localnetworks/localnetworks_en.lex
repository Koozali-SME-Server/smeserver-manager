'ln_LOCAL NETWORKS' => 'Local networks',
'Local networks' => 'Local networks',
'ln_FIRSTPAGE_DESC' => 'For security reasons, several services on your server are available only to your local network. However you can grant these  local access privileges to additional networks by listing them  below. Most installations should leave this list empty.',
'ln_ADD_TITLE' => 'Add a local network ',
'ln_ADD_DESC' =>'Each parameter must be in the form #.#.#.# (each # is a number  from 0 to 255). The server software will zero out the ending (host  identifier) part of the network address according to the subnet  mask, to ensure that the network address is valid. </P><P>  "Router" should be the IP address of the router on your local  network via which the additional network is reached.',
'ln_NETWORK_ADDRESS' => 'Network address',
'ln_SUBNET_MASK' =>  'Subnet mask',
'ln_INVALID_IP_ADDRESS' => 'Invalid IP address  - [_1]',
'ln_INVALID_SUBNET_MASK' => 'Invalid subnet mask',
'ln_REMOVE_TITLE' => 'Remove local network',
'ln_REMOVE_DESC' =>  'You are about to remove the following local network.',
'ln_REMOVE_CONFIRM' => 'Are you sure you wish to remove this network?',
'ln_DEFAULT' => 'default',
'ln_NUMBER_OF_HOSTS' => 'Number of hosts',
'ln_NOT_ACCESSIBLE_FROM_LOCAL_NETWORK' => 'Error: router address {$networkRouter} is not accessible  from local network. Did not add network.',
'ln_LOCALNETWORK_ADD'=>'Add network',
'ln_NETWORK_ALREADY_LOCAL' => ' Error: network {$network} (derived from network  {$networkAddress} and subnet mask {$networkMask})   is already considered local. Did not add new network. ',
'ln_NETWORK_ALREADY_ADDED' => 'Error: network {$network} (derived from network  {$networkAddress} and subnet mask {$networkMask})   has already been added. Did not add new network.',
'ln_ERROR_CREATING_NETWORK' => 'Error occurred while creating network.',
'ln_SUCCESS' =>'Successfully added network [_1]/[_2] via router [_3].',
'ln_SUCCESS_SINGLE_ADDRESS' =>'Successfully added network {$network}/{$networkMask} via router {$networkRouter}.  Your server will grant local access  privileges to the single IP address {$network}. ',
'ln_SUCCESS_NETWORK_RANGE' =>'Successfully added network [_1]/[_2] via router [_3]. Your server will grant local access  privileges to [_4] IP addresses in the range  [_5] to [_6]. ',
'ln_NO_SUCH_NETWORK' =>'Network not found in network db',
'ln_SUCCESS_REMOVED_NETWORK' =>'Successfully removed network [_1]/[_2] via router [_3].',
'ln_ERROR_DELETING_NETWORK' => 'Error occurred while deleting network.',
'ln_NO_ADDITIONAL_NETWORKS' => 'No additional networks',
'ln_REMOVE_HOSTS_DESC' => 'Local hosts configured on the network you are about to remove have  been detected. By default, they will also be removed. Uncheck this  box if, for some reason, you do not wish this to happen. Note that  they will not be treated as local, and may not even be reachable,  after this network is removed. ',
'ln_REMOVE_HOSTS_LABEL' => 'Remove hosts on network',
'ln_extra' => '{$network}/{$networkMask} via router  $networkRouter}.',
'ln_SUCCESS_NONSTANDARD_RANGE' =>'<p>Successfully added network [_1]/[_2] via router [_3].</p><p>  Your server will grant local access privileges to [_4] IP addresses in the range [_5] to [_6].</p><p>  Warning: the ProFTPd FTP server cannot handle this nonstandard subnet mask. The simpler specification  <b>[_7]</b> will be used instead.</p>',
