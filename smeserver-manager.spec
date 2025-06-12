Summary: Sme server  navigation module : manager 2
%define name smeserver-manager
Name: %{name}
%define version 11.0.0
%define release 90
Version: %{version}
Release: %{release}%{?dist}
License: GPL
Group: Networking/Daemons
Source: %{name}-%{version}.tar.xz
Source1: visible.png

BuildRoot: /var/tmp/%{name}-%{version}-%{release}-buildroot
BuildArchitectures: noarch
BuildRequires: smeserver-devtools
#<Build tests>
#BuildRequires:  perl >= 0:5.016
#BuildRequires:  perl(Test::More)
#BuildRequires:  perl(Test::Mojo)
#BuildRequires:  perl(Mojolicious) >= 7.56
#BuildRequires:  perl(Mojolicious::Plugin::I18N) >= 1.6
#BuildRequires:  perl(Net::Netmask) >= 1.9
#</Build tests>

Requires: smeserver-lib >= 11.0.0-13
# old manager is needed to handle access (ValidFrom)
Requires: e-smith-manager >= 2.4.0-22
Requires: smeserver-apache >= 2.6.0-19
Requires: smeserver-php >= 3.0.0-43
#Requires: smeserver-manager-locale >= 11.0.0
Requires: perl(Mojolicious) >= 8.42
Requires: perl(Mojolicious::Plugin::I18N) >= 1.6
Requires: perl(Mojolicious::Plugin::RenderFile) >= 0.12
Requires: perl(Mojolicious::Plugin::CSRFDefender) >= 0.0.8
Requires: perl(Net::Netmask) >= 1.9
Requires: perl(DBM::Deep) >= 2.0011-1
Requires: perl(Mojo::JWT) >= 0.08-1
#Requires: perl(Time::TAI64) >= 2.11
Requires: mutt >= 1.5.21
Requires: smeserver-manager-jsquery >= 1.0
Requires: smeserver-certificates >= 11.0
#Requires: js-jquery > 2.2.4-3 (optional)

Requires: smeserver-manager-locale-bg
Requires: smeserver-manager-locale-da
Requires: smeserver-manager-locale-de
Requires: smeserver-manager-locale-el
Requires: smeserver-manager-locale-es
Requires: smeserver-manager-locale-et
Requires: smeserver-manager-locale-fr
Requires: smeserver-manager-locale-he
Requires: smeserver-manager-locale-hu
Requires: smeserver-manager-locale-id
Requires: smeserver-manager-locale-it
Requires: smeserver-manager-locale-ja
Requires: smeserver-manager-locale-nb
Requires: smeserver-manager-locale-nl
Requires: smeserver-manager-locale-pl
Requires: smeserver-manager-locale-pt
Requires: smeserver-manager-locale-pt_BR
Requires: smeserver-manager-locale-ro
Requires: smeserver-manager-locale-ru
Requires: smeserver-manager-locale-sl
Requires: smeserver-manager-locale-sv
Requires: smeserver-manager-locale-th
Requires: smeserver-manager-locale-tr
Requires: smeserver-manager-locale-zh_CN
Requires: smeserver-manager-locale-zh_TW

Provides: server-manager
AutoReqProv: no

%define dir_mngr /usr/share/smanager

%description
This RPM contributes the navigation bars for the smeserver-manager. New Mojolicious version.

%prep
%setup

%build

#extract the release number and drop it in to the version for SM2 footer.
sed -i "s/our \$VERSION = '[^']*'/our \$VERSION = '%{release}'/g" root/usr/share/smanager/lib/SrvMngr.pm
year=`date +%Y`
sed -i "s/___YEAR___/$year/g" root/usr/share/smanager/lib/SrvMngr/Controller/Datetime.pm

perl createlinks

# Force creation of potentially empty directories
mkdir -p root/etc/e-smith/db/routes
mkdir -p root/home/e-smith/db/navigation2
mkdir -p root%{dir_mngr}/themes/default/public/css
mkdir -p root%{dir_mngr}/data
cp %{SOURCE1} root%{dir_mngr}/themes/default/public/images

%install
rm -rf $RPM_BUILD_ROOT
(cd root ; find . -depth -print | cpio -dump $RPM_BUILD_ROOT)
rm -f %{name}-%{version}-%{release}-filelist
/sbin/e-smith/genfilelist $RPM_BUILD_ROOT \
--dir %{dir_mngr} 'attr(0755,root,root)' \
--file %{dir_mngr}/log/development.log 'attr(0660,root,admin)' \
--file %{dir_mngr}/log/production.log 'attr(0660,root,admin)' \
--file %{dir_mngr}/script/daily.sh 'attr(0770,root,root)' \
--file %{dir_mngr}/script/routes.pl 'attr(0770,root,root)' \
--file %{dir_mngr}/script/secrets.pl 'attr(0770,root,root)' \
> %{name}-%{version}-%{release}-filelist

echo "%doc COPYING f2b/*" >> %{name}-%{version}-%{release}-filelist

%check
#cd $RPM_BUILD_ROOT/%{dir_mngr} && QUICK_TEST=1 /usr/bin/prove -q -l -r

%clean
rm -rf $RPM_BUILD_ROOT

%preun
# complete remove
if [ $1 == 0 ]
then
    systemctl stop smanager.service
    rm -f /home/e-smith/db/navigation2/*
    rm -f /home/e-smith/db/routes
    rm -f %{dir_mngr}/themes/default/public/css/*
    rm -rf %{dir_mngr}/themes/default/public/js
    find %{dir_mngr}/lib/SrvMngr/I18N/Modules -type f -name '*.pm' -exec rm '{}' \;
fi
true

%post
if [ -f /usr/share/javascript/jquery/latest/jquery.min.js ]
then
    [ -d %{dir_mngr}/themes/default/public/js ] ||
	mkdir %{dir_mngr}/themes/default/public/js
    [ -h %{dir_mngr}/themes/default/public/js/jquery.min.js ] ||
	ln -s /usr/share/javascript/jquery/latest/jquery.min.js %{dir_mngr}/themes/default/public/js/jquery.min.js
    [ -h %{dir_mngr}/themes/default/public/js/jquery.min.map ] ||
	ln -s /usr/share/javascript/jquery/latest/jquery.min.map %{dir_mngr}/themes/default/public/js/jquery.min.map
fi
true

%files -f %{name}-%{version}-%{release}-filelist
%defattr(-,root,root)

%changelog
* Thu Jun 12 2025 Brian Read <brianr@koozali.org> 11.0.0-90.sme
- Error on empty extra chars for success message [SME: 13041]
- Needed extra open for network-db after add 

* Thu Jun 12 2025 Brian Read <brianr@koozali.org> 11.0.0-89.sme
- rework navigation weights to avoid duplicates [SME: 12996]

* Mon Jun 09 2025 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-88.sme
- add datetime getYear_list [SME: 13031]
- use esmith::*DB::UTF8 to access db flat files [SME: 13027]
- fix typo [SME: 13038]

* Mon Jun 09 2025 John Crisp <jcrisp@safeandsoundit.co.uk> 11.00.0-86.sme
- Fix datetime gen_locale_date_string reference [SME: 13017]

* Mon Jun 09 2025 John Crisp <jcrisp@safeandsoundit.co.uk> 11.0.0-85.sme
- fix ln_add templates for UTF8 [SME: 13030]
- remove extraneous require line in spec file

* Mon Jun 09 2025 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-84.sme
- fix Directory caching issue [SME: 13026]
- WIP use esmith::*DB::UTF8 to access db flat files [SME: 13027]

* Mon May 05 2025 Brian Read <brianr@koozali.org> 11.0.0-83.sme
- Mod to SrvMngr-Auth to account for partials matching AdminPanels options

* Thu May 01 2025 Brian Read <brianr@koozali.org> 11.0.0-82.sme
- Correct Weights for menus [SME: 12996]

* Wed Apr 30 2025 Brian Read <brianr@koozali.org> 11.0.0-80.sme
- Remove expansion of css files from createlinks [SME: 12989]

* Wed Apr 30 2025 Brian Read <brianr@koozali.org> 11.0.0-79.sme
- Add code in SrvMngr to take note of user panel setting

* Thu Apr 17 2025 Brian Read <brianr@koozali.org> 11.0.0-78.sme
- typo in remoteaccess panel
- Fix crash in veiwlogfiles if viewlogfiles key not in DB

* Sat Apr 12 2025 Brian Read <brianr@koozali.org> 11.0.0-77.sme
- Sort out local and pulic access setting in remote panel  [SME: 12988]
- caching problem, plus confusion between normal and public setting in sshd / access in DB

* Fri Apr 11 2025 Brian Read <brianr@koozali.org> 11.0.0-76.sme
- Restore css for roundcube embedded  [SME: 12987]

* Wed Apr 09 2025 Brian Read <brianr@koozali.org> 11.0.0-75.sme
- Move review configuration to behind login [SME: 12984]
- Fix crash in port forwarding [SME: 12985]

* Wed Mar 26 2025 Brian Read <brianr@koozali.org> 11.0.0-74.sme
- Fix error message and success message format in Local Networking panel [SME: 12969]

* Tue Mar 25 2025 Brian Read <brianr@koozali.org> 11.0.0-73.sme
- Some changes to error message format in css.
- Fix DB Cache problem with port forwarding panel [SME: 12970]
- Fix error and success message display for port forwarding panel [SME: 12969]

* Mon Mar 24 2025 Brian Read <brianr@koozali.org> 11.0.0-72.sme
- Remove css files from template structure [SME: 12967]
- Rationalise and merge css files
- Adjust some gaps around panels
- Remove HR lines

* Thu Mar 20 2025 Brian Read <brianr@koozali.org> 11.0.0-71.sme
- Sort out navigation menu error on startup [SME: 12946]
- More places where floating panel needed
- Adjust floating panel to make space around it the same
- clean up some css

* Wed Mar 19 2025 Brian Read <brianr@koozali.org> 11.0.0-70.sme
- Re-cast the default theme - use proper koozali logo image, unwind multiple divs
- Enhance responsiveness
- Revert Ibay menu name to Ibays
- Remove legacy SM1 button on header
- Remove "?" access to wiki help on header

* Mon Mar 17 2025 Brian Read <brianr@koozali.org> 11.0.0-69.sme
- Add a total summary report across all existing logs [SME: 12951]

* Mon Mar 17 2025 Brian Read <brianr@koozali.org> 11.0.0-68.sme
- re-write qmailanalog for postfix [SME: 12951]
- Clean up backup.pm
- Enhance module panel - used by mail log analysis and Licence display

* Tue Mar 11 2025 Brian Read <brianr@koozali.org> 11.0.0-66.sme
- Move the button for each backup panel to the left to conform to all the other panels.

* Sun Mar 09 2025 Brian Read <brianr@koozali.org> 11.0.0-65.sme
- Sort out missing hostname on nfs and cifs workstation backup on error [SME: 12948]

* Sat Mar 08 2025 Brian Read <brianr@koozali.org> 11.0.0-64.sme
- Add code to check for boot phase completion [SME: 12953]

* Thu Mar 06 2025 Brian Read <brianr@koozali.org> 11.0.0-63.sme
- Add boot.svg image to Bug Report panel [SME: 12953]
- Move report template to inside smanager tree
- Add one-off systemd task to create boot.svg run from panel

* Tue Mar 04 2025 Brian Read <brianr@koozali.org> 11.0.0-62.sme
- Update *_en.lex files to conform to standard english punctuation  [SME: 11809]

* Tue Mar 04 2025 Brian Read <brianr@koozali.org> 11.0.0-61.sme
- Arrange for the version in the footer to be suppressed if non admin login  [SME: 12887]

* Thu Feb 27 2025 Brian Read <brianr@koozali.org> 11.0.0-60.sme
- Enhance ssh security wording to mention autoblock in remoteaccess panel  [SME: 8309]

* Thu Feb 27 2025 Brian Read <brianr@koozali.org> 11.0.0-59.sme
- Arrange for Urgent notice to be displayed if date is past Rocky 8 EOL [SME: 12918]

* Tue Feb 25 2025 Brian Read <brianr@koozali.org> 11.0.0-58.sme
- re-organise open db placement [SME: 12695]
- Re-arrange parameters to tar to avoid warning message in logs [SME: 12943]

* Fri Feb 21 2025 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-57.sme
- upgrade validate_password sub to use esmith::util [SME: 12937]
  and deduplicate code

* Thu Feb 20 2025 Brian Read <brianr@koozali.org> 11.0.0-56.sme
- open db in routes for backup controller file  [SME: 12933]
- Fix error handling for pre-backup fail [SME: 12934]

* Tue Feb 18 2025 Brian Read <brianr@koozali.org> 11.0.0-55.sme
- fix public ftp access not showing on panel [SME: 12927]

* Sat Feb 15 2025 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-54.sme
- helper to set default value of select field using protected value [SME: 12923]

* Wed Feb 12 2025 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-52.sme
- move letsencrypt panel to smeserver-certificates [SME: 12916]

* Mon Feb 10 2025 Brian Read <brianr@koozali.org> 11.0.0-51.sme
- Replace url in call to webmail by browser url rather than system host and domain [SME: 12910]
- Fix up CSS so not inline
- Sort out reveiw panel missing routines from FormMagic [SME: 12907].

* Sun Feb 09 2025 Brian Read <brianr@koozali.org> 11.0.0-50.sme
- Move all routines from FormMagic still called by SM2 panels to SM2 [SME: 12906]
- delete all references to FormMagic

* Fri Feb 07 2025 Brian Read <brianr@koozali.org> 11.0.0-49.sme
- Fix delete of ibay - typo in link
- Move across toMB() sub from formmagick to quota.pm
- Recast DB opening so it is specific to the route rather than global [SME: 12905]

* Wed Jan 29 2025 Brian Read <brianr@koozali.org> 11.0.0-48.sme
- Make Country flag display independant of the internet. [SME: 12893]

* Tue Jan 28 2025 Brian Read <brianr@koozali.org> 11.0.0-47.sme
- Temp (we hope) remove CSRF protection plugin  [SME: ]
- Fix comparison in footer with config->mode

* Tue Jan 28 2025 Brian Read <brianr@koozali.org> 11.0.0-46.sme
- Adjust conditions for showing "Reconfigure required" to only check UnSavedChanges DB entry [SME: 12891]
- Add indication of development mode in footer

* Sat Jan 25 2025 Brian Read <brianr@koozali.org> 11.0.0-45.sme
- Add some space in the reboot/reconf/shutdown panel [SME: ]
- Add check for 15 characters netbios name in workgroup panel [SME: ]
- Add action for post-upgrade-and-reboot for reconfigure panel [SME: 12865]
- Remove call to TAI64 in viewlogfiles as qmail specific format [SME: 12889]
- Add requires to pull in all the locale translation [SME: 12757]

* Fri Jan 24 2025 Brian Read <brianr@koozali.org> 11.0.0-44.sme
- Change to network-online for systemd startup to make sure network is up [SME: 12758]

* Thu Jan 23 2025 Brian Read <brianr@koozali.org> 11.0.0-43.sme
- fix access to config file though config plugin for mojo 9.39 [SME: 12885]
- Fix password setting for useraccounts and also adjust DB opens
- Add mojo version to footer for logged in [SME: 12886]
- Fix up css for red error message when multiline [SME: 12802]

* Fri Jan 17 2025 Brian Read <brianr@koozali.org> 11.0.0-42.sme
- Implement password visibility icon - [SME: 12803]

* Wed Jan 15 2025 Brian Read <brianr@koozali.org> 11.0.0-41.sme
- Add journal files to those not viewable [SME: 12870]

* Wed Jan 15 2025 Brian Read <brianr@koozali.org> 11.0.0-40.sme
- Comment out missing prefix message in navigation2-conf action and re-format it with perltidy [SME: 127672]

* Tue Jan 14 2025 Brian Read <brianr@koozali.org> 11.0.0-39.sme
- Apply perltidy to all Controller files, add .perltidy to directory and .gitignore for .tdy files (just incase) [SME: 12485]

* Sat Jan 11 2025 Brian Read <brianr@koozali.org> 11.0.0-38.sme
- Fix password reset for admin in user panel [SME: 12655]

* Thu Jan 09 2025 Brian Read <brianr@koozali.org> 11.0.0-37.sme
- Delete userpanelaccess from base (left in incorrectly after some testing)  [SME: 12839]

* Thu Jan 09 2025 Brian Read <brianr@koozali.org> 11.0.0-36.sme
- Fix spamassassin status not coming through from email filter panel to email settings panel  [SME: 12868]
- Correct spelling of API in letsencrypt panel [SME: 12864]

* Tue Dec 31 2024 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-35.sme
- fix PATH [SME: 12847]

* Tue Dec 31 2024 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-34.sme
- fix css warning xxcolor [SME: 12844]
- update CSP style rules [SME: 12840]

* Mon Dec 30 2024 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-33.sme
- host locally flag-icon.min.css 3.5.0 [SME: 12845]
- remove onclick to comply with strict CSP [SME: 12846]
- add CSP rules with specific hash [SME: 12840]

* Wed Dec 18 2024 Brian Read <brianr@koozali.org> 11.0.0-32.sme
- Fix for User and localnetwork panel [SME: 6278]
- Fix menu entry for proxy to stop it moving

* Tue Dec 17 2024 Brian Read <brianr@koozali.org> 11.0.0-31.sme
- Edit html to avoid w3c html validation warnings [SME: 6278]

* Fri Dec 13 2024 Brian Read <brianr@koozali.org> 11.0.0-30.sme
- Add in letsencrypt panel, add requires for smeserver-lib and smeserver-certificates [SME: 12810]

* Tue Nov 26 2024 Brian Read <brianr@koozali.org> 11.0.0-29.sme
- Fix remoteaccess panel, reformat pm file and bring success panel into line with other similar panels [SME: 12747]

* Fri Oct 18 2024 Brian Read <brianr@koozali.org> 11.0.0-28.sme
- Add in emailsettings for port 25,465 and 587  [SME: 12750]
- Comment out change to localhost for roundcube in _user_list email icon setting [SME: 12751]

* Sun Oct 06 2024 Brian Read <brianr@koozali.org> 11.0.0-27.sme
- Add in change to _user_list.html.ep for access to roundcube email from useraccounts [SME: 12751]

* Fri Oct 04 2024 Brian Read <brianr@koozali.org> 11.0.0-26.sme
- Add in email link to roundcube from user accounts [SME: 12751]

* Wed Oct 02 2024 Brian Read <brianr@koozali.org> 11.0.0-25.sme
- Add in cursor change when save/submit pressed to indicate processing [SME: 12748]

* Wed Oct 02 2024 Brian Read <brianr@koozali.org> 11.0.0-24.sme
- Messed up build - finger trouble [SME: 12753]

* Wed Oct 02 2024 Brian Read <brianr@koozali.org> 11.0.0-23.sme
- Add release number to footer  [SME: 12753]

* Tue Sep 24 2024 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-22.sme
- fix typos, and tidy tabs [SME: 12744]

* Mon Sep 23 2024 Brian Read <brianr@koozali.org> 11.0.0-21.sme
- Remove both option for webmail [SME: 12744]
- Add in re-open DB for portforwarding and email settings.

* Mon Sep 23 2024 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-20.sme
- webmail switch panel to use roundcube [SME: 12742]
- prevent browser from caching [SME: 12695]

* Thu Sep 05 2024 Brian Read <brianr@koozali.org> 11.0.0-19.sme
- Add in mojo plugin WithoutCache [SME: 12695]

* Sun Aug 25 2024 Brian Read <brianr@koozali.org> 11.0.0-18.sme
- Move flag to emojii from downloaded jpg. Fix singleton locale issue[SME: 12706]

* Thu Aug 22 2024 Brian Read <brianr@koozali.org> 11.0.0-17.sme
- Left Align Software Install panels Submit button [SME: 12727]

* Wed Aug 21 2024 Brian Read <brianr@koozali.org> 11.0.0-16.sme
- Typo uc DNF changed to lc dnf in Yum.pm [SME: 127245]
- Monitor dnf running using dnf status file

* Wed Aug 21 2024 Brian Read <brianr@koozali.org> 11.0.0-15.sme
- Migrate SM2 Software installer panel from use of yum to dnf [SME: 12718]

* Sun Jul 28 2024 Brian Read <brianr@koozali.org> 11.0.0-14.sme
- Version skipped due to operator error! [SME: <none> ]

* Sun Jul 28 2024 Brian Read <brianr@koozali.org> 11.0.0-13.sme
- Fix sysles.css template - overwrote it by mistake [SME: 12706]
- Also re-organised login and Legacy SM menus and help on top

* Sun Jul 28 2024 Brian Read <brianr@koozali.org> 11.0.0-12.sme
- correct positio of flag-icon [SME: 12706]

* Sat Jul 27 2024 Brian Read <brianr@koozali.org> 11.0.0-11.sme
- Add in flag icon indication of locale [SME: 12706]

* Fri Jul 26 2024 Brian Read <brianr@koozali.org> 11.0.0-10.sme
- fix navigation2.conf to more correctly translate menus [SME: 12714]

* Thu May 09 2024 Brian Read <brianr@koozali.org> 11.0.0-9.sme
- Add mojo logo to footer [SME: 12679]
- Fix default for HeaderWeight to avoid noise in logs if no Nav header in file
- Align buttons consistently [SME: 12680]

* Tue Apr 30 2024 Jean-Philippe Pialasse <jpp@koozali.org> 11.0.0-8.sme
- create dedicated log files and logrotate [SME: 12664]

* Tue Apr 30 2024 Brian Read <brianr@koozali.org> 11.0.0-7.sme
- Remove use of hel command and replace by call to BlockDevices lib [SME: 12644]

* Mon Apr 29 2024 Brian Read <brianr@koozali.org> 11.0.0-6.sme
- Update layout for table extras [SME: 12656]

* Sun Apr 28 2024 Brian Read <brianr@koozali.org> 11.0.0-5.sme
- Ibay create not getting into panel [SME: 12652]

* Tue Apr 23 2024 Brian Read <brianr@koozali.org> 11.0.0-4.sme
- add in Nav numbers for Legacypanels.pm and ignore it when generating nav menu [SME:12643]

* Thu Apr 04 2024 Brian Read <brianr@koozali.org> 11.0.0-3.sme
- Set license file to GPL2.0  [SME: 12577]

* Sat Mar 23 2024 Brian Read <brianr@koozali.org>11.0.0-2.sme
- Change Requires: e-smith- to Requires:smeserver-

* Sat Mar 23 2024 Brian Read <brianr@koozali.org>11.0.0-1.sme
- Update Release and Version to base version and 1st release for SME11 [SME: 12518]

* Fri Mar 22 2024 cvs2git.sh aka Brian Read <brianr@koozali.org> 0.1.4-34.sme
- Roll up patches and move to git repo [SME: 12338]

* Fri Mar 22 2024 BogusDateBot
- Eliminated rpmbuild "bogus date" warnings due to inconsistent weekday,
  by assuming the date is correct and changing the weekday.

* Mon Mar 04 2024 Brian Read <brianr@koozali.org> 0.1.4-33.sme
- js code to restore the menu got deleted somehow this restores it [SME: 12498]

* Wed Feb 28 2024 Brian Read <brianr@koozali.org> 0.1.4-32.sme
- Embed legacy panels [SME: 12488]

* Tue Feb 27 2024 Brian Read <brianr@koozali.org> 0.1.4-31.sme
- Sort options in mail log anaysis [SME: 11821]
- Take out qmail-q options as need to run as root or qmail - see bug:12491

* Sat Feb 24 2024 Brian Read <brianr@koozali.org> 0.1.4-30.sme
- Bring user menus into line with new menu structure  [SME: 12482]

* Fri Feb 23 2024 Brian Read <brianr@koozali.org> 0.1.4-29.sme
- Make release and version only show when logged in [SME: 12480]

* Wed Feb 21 2024 Brian Read <brianr@koozali.org> 0.1.4-28.sme
- Fix domains bug [SME: 12479]
- Fix hostnames bug [SME: 12483]

* Sun Feb 18 2024 Brian Read <brianr@koozali.org> 0.1.4-27.sme
- Re-arrange Menu [SME: 12476]
- Fix problem with ibays not all showing [SME: 12478]

* Mon Feb 12 2024 Brian Read <brianr@koozali.org> 0.1.4-26.sme
- Save and Restore menu configuration [SME: 12464]

* Thu Feb 08 2024 Brian Read <brianr@koozali.org> 0.1.4-25.sme
- Move-dataTable-js-setup-to-seperate-file [SME: 12467]

* Wed Feb 07 2024 Brian Read <brianr@koozali.org> 0.1.4-24.sme
- Add in export buttons to dataTables[SME: 12466]

* Tue Jan 30 2024 Brian Read <brianr@koozali.org> 0.1.4-23.sme
- Arrange that jquery etc is local and from rpm smeserver-manager-jsquery [SME: 12459]
- Correct position of % end in partial .html.ep files with tables in.
- Make smeserver-mananger-jsquery a requirement
- Move jquery overrides to jsquery rpm

* Sat Jan 27 2024 Brian Read <brianr@koozali.org> 0.1.4-22.sme
- Update to use jquery plugin dataTables [SME: 12458]
- Update Copyright footer to 2024
- Edit tables to have TableSort in class
- Fix up tables tbody and thead correctly
- Sort out action column to make compatible with dataTable
- Change action links to icons

* Sun Dec 03 2023 Brian Read <brianr@koozali.org> 0.1.4-21.sme
- Update CSS to provide feedback to hover and click on panel submit button  [SME: 12442]

* Tue Apr 25 2023 Michel Begue <mab974@misouk.com> 0.1.4-20.sme
- general locales for awstats [SME:12324b]
- fix reconfigure asked when not needed [SME: 12171b]
- remove unSafe status from session data

* Wed Dec 28 2022 Brian Read <brianr@bjsystems.co.uk> 0.1.4-19.sme
- Fix requires in systemd smanager.server file  [SME:12294]

* Fri Dec 09 2022 Brian Read <brianr@bjsystems.co.uk> 0.1.4-18.sme
- Fix up typo in datetime processing [SME: 11827]

* Mon Jul 18 2022 Michel Begue <mab974@misouk.com> 0.1.4-17.sme
- add forgotten password link to login panel [SME: 11816]
- update to httpd 2.4 syntax [SME: 12112]
- enable backup of /usr/share/smanager/data
- fix target in link to 'Previous SM'

* Sun Jul 17 2022 Jean-Philippe Pialasse <tests@pialasse.com> 0.1.4-16.sme
- untainting datetime [SME: 12111]

* Sun Jul 17 2022 Jean-Philippe Pialasse <tests@pialasse.com> 0.1.4-15.sme
- untainting printer [SME: 12110]

* Fri Jan 21 2022 Michel Begue <mab974@misouk.com> 0.1.4-14.sme
- Fix jquery map link missing
- Fix jquery link deleted during update
- Remove generated file during remove

* Wed Jan 05 2022 Brian Read <brianr@bjsystems.co.uk> 0.1.4-13.sme
- Update-format-for-datetime-and-reboot [SME: 11830]

* Mon Jan 03 2022 Michel Begue <mab974@misouk.com> 0.1.4-12.sme
- Add show password icon to login panel (requires jquery)
- Extend toggle hide to section menu (requires jquery)
- Set layout according to jquery presence
- Set CSRF less strict for GET method. Only if csrftoken param exists [SME: 11789]

* Mon Dec 27 2021 Michel Begue <mab974@misouk.com> 0.1.4-10.sme
- Fix empty selection list in workstation restore of backup panel [SME: 11185]

* Mon Dec 27 2021 Brian Read <brianr@bjsystems.co.uk> 0.1.4-9.sme
- format-for-dhcp-ips-in-review-config [SME: ]

* Sun Dec 26 2021 Brian Read <brianr@bjsystems.co.uk> 0.1.4-8.sme
- fix-translation-strings-with-prefix-for-review-config [SME: 11823]

* Sun Dec 26 2021 Brian Read <brianr@bjsystems.co.uk> 0.1.4-7.sme
- Sort-out-responsive-table-in-user-and-host-lists [SME: 11824]

* Sun Dec 26 2021 Brian Read <brianr@bjsystems.co.uk> 0.1.4-6.sme
- e-format html for Vistual domains inReview config to be compatible with email format list [SME 11822]

* Mon Dec 20 2021 Brian Read <brianr@bjsystems.co.uk> 0.1.4-5.sme
- Add-span-to-group-member-checkbox-list [SME: 11815]

* Mon Nov 29 2021 Brian Read <brianr@bjsystems.co.uk> 0.1.4-4.sme
- Add-dummy-classes-to-ep-files.patch [SME: 11780]

* Mon Nov 15 2021 Michel Begue <mab974@misouk.com> 0.1.4-3.sme
- Fix error message when linking, unlinking jquery in spec
- Correct the 'review' panel presentation
- Modify CSRFDefender plugin to take into account GET method
- Add TOKEN param where the GET method is used in templates
- Remove smanager from local url address

* Mon Oct 11 2021 Michel Begue <mab974@protonmail.com> 0.1.4-2.sme
- Fix incorrect list order (users, ibays, ...)
- Add external private access (remote management)
- Change CSRF error message

* Mon Jun 21 2021 Michel Begue <mab974@gmail.com> 0.1.4-1.sme
- New version: smeserver-manager-0.1.4-1 (= 0.1.2-13)

* Sat Jun 19 2021 Michel Begue <mab974@gmail.com> 0.1.2-13.sme
- Remove non english locale files (move to smeserver-manager-locale)
- Fix error in 'locale2-conf' action

* Tue Jun 15 2021 Michel Begue <mab974@gmail.com> 0.1.2-12.sme
- Fix errors in daily script
- Fix url and routes for 'hostentries' panel
- Change GET to POST method for CSRF plugin (routes and templates)
- Fix some translations

* Tue Jun 08 2021 Michel Begue <mab974@gmail.com> 0.1.2-11.sme
- Add cron job for secrets and routes purge
- Add CSRFDefender plugin against CSRF attacks
- Add optional fail2ban configuration files in doc
- Fix zh-tw locale file name
- Fix missing links in 'Bugreport'
- Fix copyright in footer
- Fix translations

* Thu Jun 03 2021 Michel Begue <mab974@gmail.com> 0.1.2-10.sme
- Add header for contrib in layout
- fix emailsettings error 'webmail is only SSL' [SME: 11443]
- fix locale files
- clean up template files

* Wed Apr 21 2021 Michel Begue <mab974@gmail.com> 0.1.2-9.sme
- Add access attribute in configuration base
- Verify modes and access compatibility
- Display theme_switch button to logged in users only [SME: 11571]

* Tue Apr 20 2021 Michel Begue <mab974@gmail.com> 0.1.2-8.sme
- Fix 'theme switch' [SME: 11571]

* Mon Apr 12 2021 Michel Begue <mab974@gmail.com> 0.1.2-7.sme
- Fix server-mode in bugreport [SME: 10448]
- Add systemd-default for smanager type (service) [SME: 11544]
- Fix smanager type and status in db
- Move initial security notification to central place
- Render 'Manual' output in template
- Add a link to koozali.org on Sme logo

* Mon Jan 25 2021 Michel Begue <mab974@gmail.com> 0.1.2-6.sme
- Fix missing backup functions
- background mode for halt and reboot
- Store debug mode in ENV
- Add a warning mode notification
- Fix some translations needing to be escaped

* Wed Jan 13 2021 Michel Begue <mab974@gmail.com> 0.1.2-5.sme
- Fix menu items not translated [SME: 11322]
- Add other locales files

* Thu Jan 07 2021 Michel Begue <mab974@gmail.com> 0.1.2-4.sme
- Fix 404 error when trailing slash is missing
- Fix missing translations for ibay and quota panels
- Comment out pptp settings in remoteaccess panel
- Fix 'sigusr1' exec for httpd  [SME: 11185]

* Tue Dec 01 2020 Michel Begue <mab974@gmail.com> 0.1.2-3.sme
- Fix download error on 'viewlogfiles' panel [SME: 11217]
- Fix duplicate entries in log files to be chosen
- Fix duplicate translation terms in 'General' lexicon

* Fri Nov 20 2020 Michel Begue <mab974@gmail.com> 0.1.2-2.sme
- Fix smanager-update event name
- Move smanager service to /usr/lib/systemd
- Fix Bugreport file download
- Fix translations missing in 'viewlogfiles'
- Remove Admin auth in httpd configuration
- Add an optional alias for admin sign in.
- Remove systemctl from .spec file

* Thu Nov 19 2020 Michel Begue <mab974@gmail.com> 0.1.2-1.sme
- Create new version smeserver-manager-0.1.2-1 (= 0.1.0-31)

* Wed Oct 07 2020 Michel Begue <mab974@gmail.com> 0.1.0-31.sme
- smanager-refresh event come back
- add smanager version in footer
- add optional refresh in layout
- fix yum logfile displaying

* Mon Oct 05 2020 Michel Begue <mab974@gmail.com> 0.1.0-30.sme
- fix I18N Namespace change for keeping Language
- clean up emailsettings code
- remove old global lexicon files
- add first simple tests
- add smanager-update event

* Mon Aug 17 2020 Michel Begue <mab974@gmail.com> 0.1.0-29.sme
- validate lexicon file before install
- fix route url construction (+)
- add authentication messages to locales

* Fri Aug 07 2020 Michel Begue <mab974@gmail.com> 0.1.0-28.sme
- validate netmask in LocalNetworks [SME: 10976]
- validate netmask in RemoteAccess [SME: 10977]
- prettier action button
- accept undescore in lexicon name
- change route urls for LocalNetworks and Portforwarding
- add rendering to LocalNetworks notification

* Mon Jul 06 2020 Michel Begue <mab974@gmail.com> 0.1.0-27.sme
- Fix typo in %post here
- Complete 'datetime' panel
- Fix notification in 'quota' panel

* Wed Jul 01 2020 Michel Begue <mab974@gmail.com> 0.1.0-26.sme
- Fix first start error
- Fix incorrect messages and various typos in modules
- Add possibility to hide menu(s) (requires jquery)

* Sat Jun 13 2020 Michel Begue <mab974@gmail.com> 0.1.0-25.sme
- Remove 'Starterwebsite' panel [SME: 8903]
- Add choice for creating Pseudonyms [SME: 9457]
- Change URL in 'useraccounts' templates
- Change app to smanager in controller 'Swttheme'

* Wed Jun 10 2020 Michel Begue <mab974@gmail.com> 0.1.0-24.sme
- Fix missing translations for some panels

* Mon Jun 08 2020 Michel Begue <mab974@gmail.com> 0.1.0-23.sme
- Transform to Mojo application (apache/mod_proxy mode)
- Add internal login and multi mode menus
- Add userpassword panel

* Fri May 08 2020 Michel Begue <mab974@gmail.com> 0.1.0-22.sme
- Fix translation in 'useraccounts' panel
- Restore theme switcher route
- Fix theme switcher redirection
- fix lexicon file not found [SME: 10927]

* Mon Apr 27 2020 Michel Begue <mab974@gmail.com> 0.1.0-21.sme
- Fix error and success management
- Optimize Routes (number)
- Delete share_dir variable
- Attach Locale lexicon to Panel and Panel?
- Fix lack of translation of first page

* Wed Apr 15 2020 Michel Begue <mab974@gmail.com> 0.1.0-20.sme
- Patch the I18N plugin to accept namespace changes
- Split global locales files to module level
- Consider additional contrib locales files
- Consider additional contrib routes and navigation item
- fix colour button in portforwarding panel
- fix missing esmith::util in starterwebsite panel

* Tue Apr 14 2020 Michel Begue <mab974@gmail.com> 0.1.0-19.sme
- Remove tests : useraccounts, wbl

* Sat Apr 11 2020 Michel Begue <mab974@gmail.com> 0.1.0-18.sme
- Add panels : emailaccess, yum, backup
- Fix Rendering comments in portforwarding & localnetworks panels
- Css and images files added (from manager).
- Initial javascript in navigation added (jQuery) -optional-
- Add 'Heading...'  navigation informations in controllers
- Show Themes_switch if there is more than one theme

* Tue Apr 07 2020 Brian Read <brianr@bjsystems.co.uk> 0.1.0-15.sme
- Sort out rule comment in portforwarding add panel

* Tue Apr 07 2020 Brian Read <brianr@bjsystems.co.uk> 0.1.0-14.sme
- Add in portforwarding panel
- Clean up localnetwork panel code

* Sun Mar 29 2020 Brian Read <brianr@bjsystems.co.uk> 0.1.0-13.sme
- Remove Db call in LN_del template
- Use Sme-error css class and make sure parameters applied to error message
- Remove creation of AdminLTE directories on install

* Fri Mar 20 2020 Brian Read <brianr@bjsystems.co.uk> 0.1.0-12.sme
- Add panels : localnetworks
- Delete AdminLTE code  - will get added into new rpm

* Sat Feb 29 2020 Michel Begue <mab974@gmail.com> 0.1.0-11.sme
- Add panels : remoteaccess, useraccounts and viewlogfiles
- Fix 'bugreport' download
- css enhancement in default theme
- Fix warnings and typos

* Wed Feb 19 2020 Michel Begue <mab974@gmail.com> 0.1.0-10.sme
- add panels : domains, hostentries and pseudonyms
- remove old navigation menu

* Mon Jan 27 2020 Michel Begue <mab974@gmail.com> 0.1.0-9.sme
- Fix messages without variables expansion
- add a theme switcher
- split navigation menu between controller and template
- template + event for .conf file

* Thu Jan 23 2020 Michel Begue <mab974@gmail.com> 0.1.0-8.sme
- Fix errors in Navigation

* Wed Jan 22 2020 Michel Begue <mab974@gmail.com> 0.1.0-7.sme
- Fix link between Navigation and Theme
- Add System and Domain names to available data (header)
- Move some data lists from template to controller (select_field)
- Integrate last Brian's changes in server-manager2.css (AdminLTE)
- Fix some warnings and typos

* Fri Jan 17 2020 Brian Read <brianr@bjsystems.co.uk> 0.1.0-6.sme
- Add in theme based on AdminLTE html template
- Fixes Server name in header (Needs Template expansion - added to Console-Save

* Sun Jan 12 2020 Michel Begue <mab974@gmail.com> 0.1.0-5.sme
- new theme to come
- css enhancement (thanks to B. Read)
- panels: reboot and ibays

* Wed Jan 01 2020 Michel Begue <mab974@gmail.com> 0.1.0-4.sme
- fix setuid with wrapper (remove sudo)
- panels quota and groups

* Mon Dec 16 2019 Michel Begue <mab974@gmail.com> 0.1.0-3.sme
- simple architecture : basic mojolicious app running
- some panels
- requires perl-Mojolicious-Plugin-I18N

* Tue Feb 06 2018 John Crisp <jcrisp@safeandsoundit.co.uk> 0.1.0-2.sme
- Start adding some template files

* Sun Feb 04 2018 Jean-Philipe Pialasse <tests@pialasse.com> 0.1.0-1.sme
- first smeserver-manager package [SME: 10506]
  this is a sandbox to dev the next server-manager based on mojolicious
  this package is based on part of the old e-smith-manager and needs it
  to work until we moved the httpd-admin part.

* Sun Apr 16 2017 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-26.sme
- add a panel to ease reporting bugs [SME: 8783]
- Original work from Mats Schuh m.schuh@neckargeo.net

* Wed Apr 05 2017 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-20.sme
- fix warning uninitialized value in lc [SME: 10209]

* Mon Mar 27 2017 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-19.sme
- fix typo in  e-smith-manager-2.8.0-bz10167-emptyback.patch

* Sat Mar 25 2017 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-18.sme
- avoid internal server error if empty back parameter [SME: 10167]
- return user friendly message

* Sat Mar 25 2017 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-17.sme
- fix too short timeout in server-manager [SME: 9921]
- now 30 min as default instead of 5
- possibility to change this and adapt the default 0.66 of timeout remaining to reset it
- by default only a session cookie, can activate persistent cookie
- sha256 as encryption.

* Mon Jan 16 2017 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-15.sme
- fix bad redirection parameter that might reveal session information to remote site [SME: 9924]

* Tue Jul 19 2016 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-13.sme
- added missing template-begin for tkt.css [SME: 9676]

* Tue Jul 19 2016 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-12.sme
- Update server-manager to Koozali branding [SME: 9676]
- We thanks John Crisp for his wonderful work.

* Wed Jun 15 2016 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-11.sme
- change link for donation to koozali.org  [SME: 9599]

* Wed Jun 15 2016 Daniel Berteaud <daniel@firewall-services.com> 2.8.0-10.sme
- Fix syntax for removing Indexes options [SME: 9587]

* Wed Jun 15 2016 Daniel Berteaud <daniel@firewall-services.com> 2.8.0-9.sme
- Remove index option for manager's resources [SME: 9587]

* Mon Jun 13 2016 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-8.sme
- fix 307 redirection to http when https is used [SME: 8825] [SME: 9583]
- update syntaxe for TKT Auth
- bump 8 for typo

* Wed Jun 1 2016 Daniel Berteaud <daniel@firewall-services.com> 2.8.0-6.sme
- Fix a syntax error in server-manager's logout script [SME: 9527]

* Wed May 11 2016 Daniel Berteaud <daniel@firewall-services.com> 2.8.0-5.sme
- Add a C wrapper to execute manager's cgi to replace perl-suid [SME: 9393]

* Wed Mar 23 2016 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-4.sme
- fix syntax for httpd 2.4 [SME: 9365]

* Fri Mar 18 2016 Jean-Philipe Pialasse <tests@pialasse.com> 2.8.0-3.sme
- rebuild for Bug [SME: 9347]
- Eliminated rpmbuild "bogus date" warnings due to inconsistent weekday,
  by assuming the date is correct and changing the weekday.
  Wed Mar 14 2000 --> Wed Mar 08 2000 or Tue Mar 14 2000 or Wed Mar 15 2000 or ....
  Wed Apr 04 2002 --> Wed Apr 03 2002 or Thu Apr 04 2002 or Wed Apr 10 2002 or ....
  Tue May 15 2008 --> Tue May 13 2008 or Thu May 15 2008 or Tue May 20 2008 or ....

* Fri Mar 18 2016 Daniel Berteaud <daniel@firewall-services.com> 2.8.0-2.sme
- Don't require perl-suidperl anymore [SME: 9339]

* Fri Feb 05 2016 stephane de Labrusse <stephdl@de-labrusse.fr> 2.8.0-1.sme
- Initial release to sme10

* Fri Feb 5 2016 Daniel Berteaud <daniel@firewall-services.com> 2.6.0-4.sme
- Really don't redirect to http when login in/out of the server-manager
  [SME: 9163]

* Sun Jan 31 2016 Daniel Berteaud <daniel@firewall-services.com> 2.6.0-3.sme
- Don't redirect to http when login in/out of the server-manager from
  localhost [SME: 9163]

* Tue Jan 6 2015 Daniel Berteaud <daniel@firewall-services.com> 2.6.0-2.sme
- Allow access to the server-manager without SSL from the loopback
  [SME: 9163]

* Sun Mar 23 2014 Ian Wells <esmith@wellsi.com> 2.6.0-1.sme
- Roll new stream to remove obsolete images [SME: 7962]

* Sun Mar 23 2014 Ian Wells <esmith@wellsi.com> 2.4.0-9.sme
- Remove references to obsolete images, by Stephane de Labrusse [SME: 7962]

* Fri Oct 11 2013 Ian Wells <esmith@wellsi.com> 2.4.0-8.sme
- Renew donation text in server-manager, by John Crisp [SME: 7897]

* Thu Jun 6 2013 Daniel Berteaud <daniel@firewall-services.com> 2.4.0-7.sme
- Do not load mod_ssl [SME: 7602]

* Wed Mar 6 2013 Shad L. Lords <slords@mail.com> 2.4.0-6.sme
- Correct path to pwauth [SME: 7319]

* Sat Feb 23 2013 Ian Wells <esmith@wellsi.com> 2.4.0-5.sme
- Correct processing of server-manager URL [SME: 7254]

* Thu Jan 31 2013 Shad L. Lords <slords@mail.com> 2.4.0-4.sme
- Fix typo in perl(Apache::AuthTkt) requires [SME: 7236]

* Thu Jan 31 2013 Shad L. Lords <slords@mail.com> 2.4.0-3.sme
- Add perl-suidperl dependency [SME: 7235]

* Thu Jan 31 2013 Shad L. Lords <slords@mail.com> 2.4.0-2.sme
- Add perl(Apache::AuthTkt) dependency [SME: 7236]

* Thu Jan 31 2013 Shad L. Lords <slords@mail.com> 2.4.0-1.sme
- Roll new stream for sme9

* Sat Aug 7 2010 Ian Wells <esmith@wellsi.com> 2.2.0-6.sme
- Remove empty <p> tag from /etc/e-smith/web/common/foot.tmpl, by Daniel [SME: 5905]

* Sun Jan 31 2010 Jonathan Martens <smeserver-contribs@snetram.nl> 2.2.0-5.sme
- Only display error messages intended for admin in server-manager [SME: 5700]

* Wed Dec  9 2009 Charlie Brady <charlieb@budge.apana.org.au> 2.2.0-4.sme
- Fix css validation errors. [SME: 5656]

* Fri Sep 18 2009 Stephen Noble <support@dungog.net> 2.2.0-4.sme
- display reconfigure warning once if UnsavedChanges=yes [SME: 5475]

* Fri Sep 18 2009 Stephen Noble <support@dungog.net> 2.2.0-3.sme
- display reconfigure warning if UnsavedChanges=yes [SME: 5475]

* Sun Apr 26 2009 Jonathan Martens <smeserver-contribs@snetram.nl> 2.2.0-2.sme
- Fix misinterpretation of display string [SME: 5022]

* Tue Oct 7 2008 Shad L. Lords <slords@mail.com> 2.2.0-1.sme
- Roll new stream to separate sme7/sme8 trees [SME: 4633]

* Sat Oct 4 2008 Shad L. Lords <slords@mail.com> 1.14.0-20
- Make navigation use new db class for navigation [SME: 4619]

* Thu Jul 31 2008 Shad L. Lords <slords@mail.com> 1.14.0-19
- Make binmode properties of db class [SME: 4317]
- Add new navigation db & utf8 classes [SME: 4317]

* Tue Jul 1 2008 Shad L. Lords <slords@mail.com> 1.14.0-18
- Fix open of database to create if necessary [SME: 4147]

* Thu May 15 2008 Shad L. Lords <slords@mail.com> 1.14.0-17
  Tue May 15 2008 --> Tue May 13 2008 or Thu May 15 2008 or Tue May 20 2008 or ....
- No longer remove navigation dbs. [SME: 4147]
- Deal a little more gracefully with non UTF-8 lexicons [SME: 4229]

* Mon Mar 31 2008 Shad L. Lords <slords@mail.com> 1.14.0-16
- Remove navigation dbs and create new [SME: 4147]

* Fri Mar 28 2008 Shad L. Lords <slords@mail.com> 1.14.0-15
- Remove last remnant of pleasewait [SME: 4130]

* Wed Mar 26 2008 Shad L. Lords <slords@mail.com> 1.14.0-14
- Include general lexicons in nav-config [SME: 4113]

* Tue Mar 25 2008 Shad L. Lords <slords@mail.com> 1.14.0-13
- Fix wide output to print in navigation and allow navigations db to
  be utf8 [SME: 4101]

* Sat Mar 22 2008 Shad L. Lords <slords@mail.com> 1.14.0-12
- Fix UTF-8 encoding in header and nav-conf [SME: 4072]

* Tue Jan 08 2008 Stephen Noble <support@dungog.net> 1.14.0-11
- Fix to remove spaces and newlines in panel headers [SME: 3346]

* Tue Jan 08 2008 Stephen Noble <support@dungog.net> 1.14.0-10
- remove the FormMagick session files [SME: 3723]

* Tue Jan 08 2008 Stephen Noble <support@dungog.net> 1.14.0-9
- Remove spaces and newlines in panel headers [SME: 3346]

* Sun Jul 01 2007 Shad L. Lords <slords@mail.com> 1.14.0-8
- Make login/logout no quite so verbose. [SME: 2660]

* Fri May 18 2007 Shad L. Lords <slords@mail.com> 1.14.0-7
- Use correct lib for modules

* Sun Apr 29 2007 Shad L. Lords <slords@mail.com>
- Clean up spec so package can be built by koji/plague

* Mon Apr 9 2007 Stephen Noble <support@dungog.net> 1.14.0-6
- Convert http to https [SME: 2577]

* Mon Mar 12 2007 Gavin Weight <gweight@gmail.com> 1.14.0-5
- Restyle the SME Server manager login form. [SME: 2666]

* Mon Mar 05 2007 Shad L. Lords <slords@mail.com> 1.14.0-4
- Don't pass domain in ticket cookie (logout) unless it contains a dot [SME: 2402]

* Mon Mar 05 2007 Shad L. Lords <slords@mail.com> 1.14.0-3
- Don't pass domain in ticket cookie (login) unless it contains a dot [SME: 2402]

* Tue Feb 13 2007 Charlie Brady <charlie_brady@mitel.com> 1.14.0-2
- Deal gracefully with renamed apache modules. [SME: 2471]

* Fri Jan 26 2007 Shad L. Lords <slords@mail.com> 1.14.0-1
- Roll stable stream. [SME: 2328]

* Fri Jan 19 2007 Shad L. Lords <slords@mail.com> 1.13.1-13
- Create /etc/httpd/admin-conf directory

* Fri Jan 19 2007 Shad L. Lords <slords@mail.com> 1.13.1-12
- Move apache logrotate to e-smith-apache.
- Put quotes around 'httpd-admin' in hashes.

* Thu Jan 18 2007 Shad L. Lords <slords@mail.com> 1.13.1-11
- Move last httpd fragments from e-smith-base.

* Thu Dec 07 2006 Shad L. Lords <slords@mail.com>
- Update to new release naming.  No functional changes.
- Make Packager generic

* Mon Nov 27 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-09
- Randomize string used for encrypting auth tickets.

* Tue Nov 21 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-08
- Add ProxyPassReverse entries for server-manager passthroughs, so that
  redirects work correctly.

* Thu Nov 16 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-07
- Add basic L10N in navigation-conf.

* Wed Nov 15 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-06
- Avoid use of FormMagick in navigation-conf. TODO: fix I18N.

* Mon Nov 06 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-05
- Simplify the sorting code in navigation (so that I can understand
  it).

* Mon Nov 06 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-04
- Simplify javascript, and remove use of pleasewait script.

* Mon Nov 06 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-03
- Move swapClass javascript out of standard header and into just
  navigation.

* Fri Nov 03 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-02
- Use mod_auth_tkt authentication for server manager access.

* Thu Nov 02 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.1-01
- Add branch tag and roll new development version.

* Wed Nov 01 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.0-06
- Move httpd-admin and its configuration templates from e-smith-base RPM.
  [SME: 2023]

* Wed Nov 01 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.0-05
- Move more server-manager components from e-smith-base RPM. [SME: 2023]

* Wed Nov 01 2006 Charlie Brady <charlie_brady@mitel.com> 1.13.0-04
- Add manager header/footer templates (moved from e-smith-base)
  [SME: 2023]

* Wed Aug 2 2006 Michael Soulier <msoulier@digitaltorque.ca>
- [1.13.0-03]
- Fixing broken db path in patch. [SME: 107]

* Wed Mar 29 2006 Michael Soulier <michael_soulier@mitel.com>
- [1.13.0-02]
- Forward porting arbitrary menu plugins. [SME: 107]

* Wed Mar 29 2006 Michael Soulier <michael_soulier@mitel.com>
- [1.13.0-01]
- Rolling to dev.
  [SME: 107]

* Wed Mar 15 2006 Charlie Brady <charlie_brady@mitel.com> 1.12.0-01
- Roll stable stream version. [SME: 1016]

* Tue Jan 31 2006 Gordon Rowell <gordonr@gormand.com.au> 1.11.0-13
- Changed the static CSS files into directory templates, which are
  expanded in bootstrap-console-save [SME: 408]

* Wed Nov 30 2005 Gordon Rowell <gordonr@gormand.com.au> 1.11.0-12
- Bump release number only

* Sun Oct 16 2005 Gordon Rowell <gordonr@e-smith.com>
- [1.11.0-11]
- Removed "table-layout: fixed;" from sme_main.css [SF: 1299779]

* Sun Oct 16 2005 Gordon Rowell <gordonr@e-smith.com>
- [1.11.0-10]
- dos2unix conversion on CSS files [SF: 1299779]

* Wed Aug 17 2005 Charlie Brady <charlieb@e-smith.com>
- [1.11.0-09]
- Remove bogus "Provides: perl(I18N::AcceptLanguage)" header. [SF: 1262438]

* Thu Jun  9 2005 Charlie Brady <charlieb@e-smith.com>
- [1.11.0-08]
- Add newly required manager/cgi-bin/{navigation,noframes} symlinks.
  [SF: 1217426]

* Tue Jun  7 2005 Charlie Brady <charlieb@e-smith.com>
- [1.11.0-07]
- Remove references to /etc/e-smith/web/panel/manager/common
  [SF: 1172203, 1210715]

* Tue Sep 28 2004 Michael Soulier <msoulier@e-smith.com>
- [1.11.0-06]
- Updated perl dependencies. [msoulier MN00040240]

* Tue Jul 13 2004 Michael Soulier <msoulier@e-smith.com>
- [1.11.0-05]
- Added the sme_panel_menu.css file, for tabbed menu support. Added a link to
  it in the standard header.
  [msoulier MN00030141]

* Thu Feb 26 2004 Michael Soulier <msoulier@e-smith.com>
- [1.11.0-04]
- Backed-out previous change. It was better before. [msoulier dpar-22042]

* Thu Feb 26 2004 Michael Soulier <msoulier@e-smith.com>
- [1.11.0-03]
- Added vertical-align: text-top; to td.sme-noborders-label to ensure that
  text is aligned vertically at the top of the cell. [msoulier dpar-22042]

* Tue Jul  8 2003 Charlie Brady <charlieb@e-smith.com>
- [1.11.0-02]
- Check that files are executable before listing in the
  manager navigation frame. [charlieb 9197]
- s/Copyright/License/.

* Tue Jul  8 2003 Charlie Brady <charlieb@e-smith.com>
- [1.11.0-01]
- Changing version to development stream number - 1.11.0

* Thu Jun 26 2003 Charlie Brady <charlieb@e-smith.com>
- [1.10.0-01]
- Changing version to stable stream number - 1.10.0

* Mon Apr 21 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-16]
- New class for error link within table cell [gordonr 8129]

* Tue Apr  8 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-15]
- Removed borders around "warning" cells so they don't look like
  they are bleeding on some browsers (e.g. Mozilla) [gordonr 8127]

* Thu Apr  3 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-14]
- Make <h2> and <p> within div.{success,error} => {red,green} [gordonr 7919]

* Wed Apr  2 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-13]
- Moved manager SSL fragments back to e-smith-base [gordonr 7900]

* Tue Apr  1 2003 Tony Clayton <apc@e-smith.com>
- [1.9.5-12]
- add td.sme-radiobutton css class for date/time panel [tonyc 1588]

* Tue Apr  1 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-11]
- Make the question make bold [gordonr 7946]

* Tue Apr  1 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-10]
- Fix SSL listen template for serveronly mode [gordonr 7900]

* Tue Apr  1 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-09]
- Bind manager on port 981 to localhost only [gordonr 7900]

* Mon Mar 31 2003 Mike Dickson <miked@e-smith.com>
- [1.9.5-08]
- changed class for sme-noborders-label to width=33% rather than
  a fixed 250px wide, due to limitations in IE6 [miked 7676]
- added class "sectionbar" for use [miked]
- modified "td.noborders-label" colour [miked]


* Fri Mar 28 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-07]
- Changed Copyright font from 8px to 10px [gordonr 7676]

* Thu Mar 27 2003 Mark Knox <markk@e-smith.com>
- [1.9.5-06]
- Changed Help -> ? and changed formatting of current user and host [markk
  7707]

* Thu Mar 20 2003 Tony Clayton <apc@e-smith.com>
- [1.9.5-05]
- Add css style for a.error class [tonyc 4718]

* Wed Mar 19 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.5-04]
- Move navigation dbs to /home/e-smith/db/navigation. We shouldn't generate
  them in /etc/e-smith/locale and we should name them by language, in case
  we share lexicons (e.g. fr/fr-ca) [gordonr 7733]

* Sun Mar 16 2003 Mike Dickson <miked@e-smith.com>
- [1.9.5-03]
- stylesheet fixes: darkend the copyrigt text, adjuste the UL and LI tags [miked 7676]

* Thu Mar 13 2003 Mark Knox <markk@e-smith.com>
- [1.9.5-02]
- Removed 40LogoRow from header.htm templates [markk 4722]

* Thu Mar 13 2003 Mark Knox <markk@e-smith.com>
- [1.9.5-01]
- Removed product_logo.gif [markk 4722]

* Tue Mar 11 2003 Mike Dickson <miked@e-smith.com>
- [1.9.4-09]
- changed Adming to admin in header.htm templates [miked 7595]

* Thu Feb  6 2003 Mike Dickson <miked@e-smith.com>
- [1.9.4-08]
- updated the CSS to add a new "success" class [miked 7032]

* Tue Feb  4 2003 Mark Knox <markk@e-smith.com>
- [1.9.4-07]
- Refer to new SSL cert name of $SystemName.$DomainName [markk 4874]

* Mon Feb  3 2003 Mark Knox <markk@e-smith.com>
- [1.9.4-06]
- Include ValidFrom hosts in SSL allow statements [markk 6428]

* Mon Feb  3 2003 Mark Knox <markk@e-smith.com>
- [1.9.4-05]
- Also Listen on the right ports [markk 6428]

* Mon Feb  3 2003 Mark Knox <markk@e-smith.com>
- [1.9.4-04]
- Bind SSL to port 443 if no primary web server available [markk 6428]

* Sat Jan 25 2003 Mike Dickson <miked@e-smith.com>
- [1.9.4-03]
- darkened colour of copyright text [miked 6696]

* Sat Jan 25 2003 Mike Dickson <miked@e-smith.com>
- [1.9.4-02]
- removed demo class "warn" from nav script [miked 6706]

* Mon Jan 13 2003 Mike Dickson <miked@e-smith.com>
- [1.9.4-01]
- updated CSS file to show correct colour in menu, added "warn.gif" [miked 6398]

* Fri Jan  3 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.3-13]
- Made use of esmith::I18N in navigation-conf. Renamed locale->lang
  to make it more obvious that we are dealing with a langtag [gordonr 5212]

* Thu Jan  2 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.3-12]
- Hide online-manual from navigation bar - now in header Help [gordonr 6394]

* Wed Jan  1 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.3-11]
- Updated navigation script to use esmith::I18N [gordonr 5212]

* Wed Jan  1 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.3-10]
- Spell bootstrap-console-save correctly [gordonr 5493]

* Wed Jan  1 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.3-09]
- Work out the correct navigation.info based on browser language [gordonr 5493]

* Wed Jan  1 2003 Gordon Rowell <gordonr@e-smith.com>
- [1.9.3-08]
- Generate navigation.info files (config db format) for each supported
  language in /etc/e-smith/locale/{language}/etc/e-smith/web/functions
- Read the navigation.info file for the preferred language when
  displaying the navigation bar
- TODO: Actually select the correct navigation.info file [gordonr 5493]

* Tue Dec 31 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.9.3-07]
- Skip non-executable files when generating nav bar [gordonr 5802]

* Fri Dec 27 2002 Mike Dickson <miked@e-smith.com>
- [1.9.3-06]
- updates and comments in the CSS files [miked 3185]
- commented out the two links in the header that are not ready yet
  (log out and update available) [miked 5967 and 492]

* Mon Dec 16 2002 Mike Dickson <miked@e-smith.com>
- [1.9.3-05]
- UI Update, part of the tweaking for the new UI [miked 5494]

* Tue Dec 10 2002 Mike Dickson <miked@e-smith.com>
- [1.9.3-04]
- forgot to update header.htm fragments [miked 5494]

* Mon Dec  9 2002 Mike Dickson <miked@e-smith.com>
- [1.9.3-03]
- ui update [miked 5494]

* Mon Dec  2 2002 Mike Dickson <miked@e-smith.com>
- [1.9.3-02]
- ui update  [miked 5494]

* Wed Nov 27 2002 Mike Dickson <miked@e-smith.com>
- [1.9.3-01]
- and again to make it stick

* Wed Nov 27 2002 Mike Dickson <miked@e-smith.com>
- [1.9.2-01]
- updated the header images [miked 5529]
- updated other UI stuff [miked 5494]

* Fri Nov 22 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.9.1-02]
- templated header.htm [miked 5826]
- modified header.htm template to link to online-manual and blades
  [gordonr 5826]

* Thu Nov 21 2002 Mike Dickson <miked@e-smith.com>
- [1.9.1-01]
- update to new UI system [miked 5494]

* Wed Nov 20 2002 Mike Dickson <miked@e-smith.com>
- [1.9.0-01]
- Changing to development stream; version upped to 1.9.0

* Fri Oct 11 2002 Charlie Brady <charlieb@e-smith.com>
- [1.8.0-01]
- Roll to maintained version number to 1.8.0

* Wed Jun 19 2002 Mark Knox <markk@e-smith.com>
- [1.7.2-01]
- Move SSL mutex and cache out of /var/log [markk 3830]

* Tue Jun 18 2002 Charlie Brady <charlieb@e-smith.com>
- [1.7.1-01]
- Move admin apache SSL mutex and SSL session cache to files named admin_xxx
  to avoid name clash with main server. [charlieb 3830]

* Wed Jun  5 2002 Charlie Brady <charlieb@e-smith.com>
- [1.7.0-01]
- Changing version to maintained stream number to 1.7.0

* Fri May 31 2002 Charlie Brady <charlieb@e-smith.com>
- [1.6.0-01]
- Changing version to maintained stream number to 1.6.0

* Thu May 23 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.5.11-01]
- RPM rebuild forced by cvsroot2rpm

* Thu May 16 2002 Tony Clayton <apc@e-smith.com>
- [1.5.10-01]
- Pass noframes=1 as cgi param for browsers without frames [tonyc 3475]

* Thu May 16 2002 Tony Clayton <apc@e-smith.com>
- [1.5.9-01]
- use Dan McGarry's manager.css/navigation fixes for 3377 [tonyc]

* Thu May 16 2002 Tony Clayton <apc@e-smith.com>
- [1.5.8-01]
- Remove unnecessary <p> tags in navigation html [tonyc 3377]
- Fix navigation panel to not import symbols from fm subclasses
  [tonyc 3109]

* Mon May 13 2002 Tony Clayton <apc@e-smith.com>
- [1.5.7-01]
- Fix navigation panel to play nice with FM subclasses [tonyc 3109]

* Fri May 10 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.5.6-01]
- Tell CGI.pm to not produce xhtml [gordonr 3377]

* Tue May  7 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.5.5-01]
- Missing use esmith::util [gordonr 3372]

* Wed Apr 24 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.5.4-01]
- Ignore cgi-bin/internal-.* in navigation [gordonr 3202]

* Mon Apr 22 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.5.3-01]
- Back out gettext() calls - esmith::FormMagic was Croaking on
  bad lexicons for old panels. Now properly localises the navigation
  bar if the localisations exist [gordonr 3155]

* Fri Apr 19 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.5.2-01]
- Added explicit gettext() call to localize navigation bar while
  figuring out esmith::FormMagick won't do it for me [gordonr 3155]

* Wed Apr 10 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.5.1-01]
- navigation is now polymorphic and does noframes as well [gordonr #3155]

* Thu Apr 04 2002 Gordon Rowell <gordonr@e-smith.com>
  Wed Apr 04 2002 --> Wed Apr 03 2002 or Thu Apr 04 2002 or Wed Apr 10 2002 or ....
- [1.5.0-01]
- Rolled to development stream [gordonr]

* Wed Apr 03 2002 Kirrily Robert <skud@e-smith.com>
- [1.4.4-01]
- Added red error messages to CSS [skud 3027]

* Thu Mar 14 2002 Gordon Rowell <gordonr@e-smith.com>
- [1.4.3-01]
- Fixed regexp for ignoring pleasewait(-.*?). Two each in
  pleasewait/noframes. Reduced to one in each [gordonr]

* Fri Mar 1 2002 Tony Clayton <tonyc@e-smith.com>
- [1.4.2-01]
- rollRPM: Rolled version number to 1.4.2-01. Includes patches up to 1.4.1-02.
- mkdir panels/manager/common in spec file for CVS migration

* Fri Jan 25 2002 Tony Clayton <tonyc@e-smith.com>
- [1.4.1-02]
- added missing ')' in navigation script pleasewait munging

* Fri Jan 25 2002 Tony Clayton <tonyc@e-smith.com>
- [1.4.1-01]
- rollRPM: Rolled version number to 1.4.1-01. Includes patches up to 1.4.0-02.
- navigation now ignores pleasewait-* files

* Thu Jan 10 2002 Charlie Brady <charlieb@e-smith.com>
- [1.4.0-02]
- Use dated log file for ssl_engine_log. Name the file ssl_engine_log.xxxxx
  to keep it distinct from the main web server's log file.

* Tue Dec 11 2001 Jason Miller <jay@e-smith.com>
- [1.4.0-01]
- rollRPM: Rolled version number to 1.4.0-01. Includes patches up to 1.3.0-07.

* Sat Dec 08 2001 Charlie Brady <charlieb@e-smith.com>
- [1.3.0-07]
- Move genNavigationHeader() down below the script grokking code in
  "navigation", to help Netscape's faulty rendering.

* Wed Nov 21 2001 Charlie Brady <charlieb@e-smith.com>
- [1.3.0-06]
- Remove troublesome "Requires: e-smith-base".
- Remove obsolete "Requires: e-smith".

* Thu Nov 1 2001 Gordon Rowell <gordonr@e-smith.com>
- [1.3.0-05]
- Indent description within navigation headings sections

* Thu Nov 1 2001 Gordon Rowell <gordonr@e-smith.com>
- [1.3.0-04]
- Backed out patch from 1.3.0-02 - restored image to navigation frame

* Wed Oct 31 2001 Charlie Brady <charlieb@e-smith.com>
- [1.3.0-03]
- Add Mitel branding changes.

* Fri Aug 31 2001 Gordon Rowell <gordonr@e-smith.com>
- [1.3.0-02]
- Removed image from top of navigation - now in separate frame
- Added Provides: server-manager

* Fri Aug 31 2001 Gordon Rowell <gordonr@e-smith.com>
- [1.3.0-01]
- Rolled version number to 1.3.0-01. Includes patches upto 1.2.0-02.

* Fri Aug 17 2001 gordonr
- [1.2.0-02]
- Autorebuild by rebuildRPM

* Wed Aug 8 2001 Charlie Brady <charlieb@e-smith.com>
- [1.2.0-01]
- Rolled version number to 1.2.0-01. Includes patches upto 1.1.0-04.

* Tue Jul 31 2001 Adrian Chung <adrianc@e-smith.com>
- [1.1.0-04]
- moving manager.css file from manager/html to common/css

* Tue Jul 31 2001 Adrian Chung <adrianc@e-smith.com>
- [1.1.0-03]
- Adding SSL enabling templates for port 981.
- Adding 01localAccessString fragment for use in SSL
  enabling templates.

* Fri Jul 27 2001 Charlie Brady <charlieb@e-smith.com>
- [1.1.0-02]
- Prepend "/server-manager" to hrefs, to allow consistent path interpretation
  between admin and standard web server.

* Fri Jul 27 2001 Charlie Brady <charlieb@e-smith.com>
- [1.1.0-01]
- Rolled version number to 1.1.0-01. Includes patches upto 0.1.1-06.

* Tue Jul 24 2001 Adrian Chung <adrianc@e-smith.com>
- [0.1.1-06]
- Incorporating font size changes to manager.css

* Mon Jul 9 2001 Peter Samuel <peters@e-smith.com>
- [0.1.1-05]
- Updated packager information

* Fri Jul 6 2001 Peter Samuel <peters@e-smith.com>
- [0.1.1-04]
- Changed license to GPL

* Wed Jun 06 2001 Charlie Brady <charlieb@e-smith.com>
- [0.1.1-03]
- Change font setting in navigation - use css class instead.
- Add newlines after each link in navigation frame - so that HTML
  source is readable.
- Add manager.css, which came from e-smith-base. Let's have all look&feel
  in the one RPM.
- Check whether "files" in cgi-bin directory are actually directories. Skip
  any directories.

* Mon Apr  9 2001 Adrian Chung <adrianc@e-smith.com>
- [0.1.1-02]
- changing CELLPADDING in navigation from 4 to 2.

* Tue Mar 14 2000 Charlie Brady <charlieb@e-smith.com>
  Wed Mar 14 2000 --> Wed Mar 08 2000 or Tue Mar 14 2000 or Wed Mar 15 2000 or ....
- initial release
