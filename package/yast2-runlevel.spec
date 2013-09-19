#
# spec file for package yast2-runlevel
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-runlevel
Version:        3.1.0
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0+
BuildRequires:	perl-XML-Writer update-desktop-files yast2 yast2-testsuite
BuildRequires:  yast2-devtools >= 3.0.6

# Don't use Info function to check enable state (bnc#807507)
BuildRequires:	yast2 >= 2.23.23
# Wizard::SetDesktopTitleAndIcon
Requires:	yast2 >= 2.21.22

Provides:	yast2-config-runlevel
Obsoletes:	yast2-config-runlevel
Provides:	yast2-trans-runlevel
Obsoletes:	yast2-trans-runlevel
BuildArchitectures:     noarch
Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Runlevel Editor

%description
This package allows you to specify which services will be run at system
boot.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_desktopdir}
%{yast_desktopdir}/runlevel.desktop
%dir %{yast_scrconfdir}
%{yast_scrconfdir}/*.scr
%dir %{yast_clientdir}
%{yast_clientdir}/*.rb
%dir %{yast_yncludedir}/runlevel
%{yast_yncludedir}/runlevel/*.rb
%dir %{yast_moduledir}
%{yast_moduledir}/*.rb
%{yast_schemadir}/autoyast/rnc/*.rnc
%doc %{yast_docdir}
