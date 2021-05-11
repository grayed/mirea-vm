# mirea-vm

This toolset helps to build virtual machines infrastructure
for students, based on OpenBSD.

Example configuration assumes having two auxiliary machines:
a gateway, named 'gw', and storage, named 'stor'.

Also, full control on MAC addressing and IP addressing is assumed.
In particular, the 10/8 network usage is hardcoded.
Almost everything else is tweakable: just add local.conf in
the directory with `Makefile` and set appropriate variables.

## Input files

Information about students should be put in files `groups/*.group'.
Those files are text ones with the following structure:

	NUMBER  LOGIN  PASSWORD  NAME

where `NUMBER` is ordinal number of student in group (must not change!),
`LOGIN` is his/her desired login name, `PASSWORD` is his/her password
in encrypted form (see [https://man.openbsd.org/encrypt.1](encrypt\(1\))
and `NAME` is student's name of arbitrary form and length (spaces are allowed).
Here's an example:

	1 st23 $2b$08$jRgogpNzcr4Rtff2WnWx1uWK0G91GoNIxDfEuCcx5t18zxrRUZh1q John Doe
	2 st25 $2b$08$ck2jZYfY8cUtHe.yplMtROMiokBQ/9Hz3z9qereUsSSmgCN4hLsVK Anna Karenina
	4 st42 $2b$08$kWzw8zZaR6hOadWd61Vxy.Z.LIUAX8Qvf2reqDpE2pO5uovxHacAS Kernel McKusick

Note that login names are compound of 'st' prefix (could be changed via LOGIN_PREFIX)
and numeric ID. This ID is used e.g. to generate port numbers for incoming SSH connections.

Group files themselves must follow the following naming scheme:

	FLOW_YEAR_NUMBER.group

Here `FLOW` is one of the registered in `groups/flows.list` values.
`YEAR` is a two-digit number of group's year; it doesn't have any special meaning, and is used
only for distinction purposes.
`NUMBER` is just ordinal number of the group in the given year's flow.

## Gateway

Runs DHCP server and nameserver. Also, it does SSH redirections to VMs via PF.
To build configuration for those, run:

	make gw

Look at the generated files, then apply configuration:

	make install-gw

## Storage

Contains installation sets and answers, and serves them (e.g., over HTTP(S)).
To build those, run:

	make stor

If everything is good, put generated `FOO-install.conf` and `siteXY.tgz`
files in the place they belong:

	make install-stor
