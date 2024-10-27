# <img src="https://www.koozali.org/images/koozali/Logo/Png/Koozali_logo_2016.png" width="25%" vertical="auto" style="vertical-align:bottom"> smeserver-manager

SMEServer Koozali developed git repo for smeserver-manager smeserver

## Wiki
<br />https://wiki.koozali.org/Crontab_Manager
<br />https://wiki.koozali.org/Disk_Manager
<br />https://wiki.koozali.org/Crontab_Manager/fr
<br />https://wiki.koozali.org/Qmhandle_mail_queue_manager
<br />https://wiki.koozali.org/Customize_Server-Manager_Appearance
<br />https://wiki.koozali.org/Modules_and_Server_Manager_Panels
<br />https://wiki.koozali.org/Create_server-manager_panels_by_perl_cgi_(deprecated)
<br />https://wiki.koozali.org/Server_Manager_2_Howto_incorporate_a_legacy_contrib

## Bugzilla
Show list of outstanding bugs: [here](https://bugs.koozali.org/buglist.cgi?quicksearch=smeserver-manager)

## Description

The *smeserver-manager* is a web-based management interface for the SME Server (formerly known as e-smith server and gateway). SME Server is a Linux-based distribution designed for small to medium-sized enterprises, providing a wide range of network services and simplified server management.

It is based on the perl Mojolicious package. Mojolicious is a real-time web framework for Perl, which provides a range of functionalities that make it a powerful and flexible tool for web development.

### Features

#### Web-Based Management Interface:
smeserver-manager provides an intuitive and user-friendly web interface that allows administrators to manage various aspects of the server without needing deep technical knowledge or command-line skills.

#### User and Group Management:
It allows you to easily add, remove, and manage user accounts and groups. The interface simplifies creating email accounts, setting passwords, and configuring user permissions.

#### Network Configuration:
You can configures network settings such as IP addresses, DNS, DHCP, and gateway settings. The interface also provides options for setting up VPNs, remote access, and firewall rules.

#### File Sharing and Storage:
Enables and manages file sharing services like Samba (for Windows file sharing) and NFS (for Unix/Linux file sharing). Administrators can easily create shared folders and manage permissions.

#### Email Services:
Configure and manage email services, including setting up mail domains, user mailboxes, and SMTP/IMAP/POP3 settings. It also provides options for spam and virus filtering.

#### Web Services:
Host and manage websites using the integrated web server (usually Apache). It supports virtual hosting, where multiple websites can be hosted on the same server.

#### Backup and Restore:
Perform backups of essential data and server configurations. The interface provides options for scheduled backups and restoring from backup files.

#### Software Updates and Installation:
Keep the server up-to-date with the latest security patches and software updates. The interface helps in installing and updating software packages and extensions.

#### Monitoring and Reporting:
Monitor server performance and health. The interface provides logs, status reports, and alerts for various server components, including disk usage, network traffic, and system load.


### Installation and Access

Typically, smeserver-manager is installed by default on SME Server. To access the interface:

Open a web browser on a device connected to the same network as the SME Server. Enter the server's IP address or hostname followed by /server-manager in the address bar (e.g., https://192.168.1.1/server-manager). 
You will be prompted to log in. Use the administrator credentials set during the SME Server installation.

### Benefits

Simplicity: Makes it easy for non-technical users to manage a server.
Centralized Management: Provides a single point of control for various server functionalities.
Efficiency: Saves time and reduces complexity in server management tasks.
Security: Regular updates and built-in security features ensure the server remains secure.

### Considerations

Learning Curve: While designed to be user-friendly, some features may still require a basic understanding of server and network management concepts.
Dependencies: Relies on specific packages and configurations of SME Server, and may not be directly applicable to other Linux distributions.

### Summary

SMEserver-manager is a powerful tool that brings simplicity and efficiency to server management for small to medium-sized enterprises. By providing a centralized, web-based interface, it allows administrators to manage users, network settings, file sharing, email services, web hosting, and more, all from a single location.