# mirea-vm

This toolset helps to build virtual machines infrastructure
for students, based on OpenBSD.

Example configuration assumes having two auxiliary machines:
a gateway, named 'gw', and storage, named 'stor'.

Also, full control on MAC addressing and IP addressing is assumed.
In particular, the 10/8 network usage is hardcoded.
Almost everything else is tweakable, see below.

## Setting up

First, you need to install the ipv6calc package.

Then you should create the file `local.conf` in the same directory with `Makefile`.
Set any variables you need to change there; it will be included by `Makefile`.
You can use any value mentioned in `Makefile` up to the line
telling that there are no more customizable items.

Information about students should be put in files `groups/*.group'.
Those files are text ones with the following structure:

	NUMBER  LOGIN  PASSWORD  NAME

where `NUMBER` is ordinal number of student in group (must not change!),
`LOGIN` is his/her desired login name, `PASSWORD` is his/her password
in encrypted form (see [encrypt\(1\)](https://man.openbsd.org/encrypt.1))
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

Group files must reside in `groups` subdirectory.

The `site` subdirectory should contain files that will go in `siteXY.tgz`.
The `templates` subdirectory should contain skeleton files used to build actual configuration.
Feel free to modify files in both of them.

## Gateway

Runs DHCP server and nameserver. Also, it does SSH redirections to VMs via PF.
To build configuration for those, run:

	make gw

Look at the generated files, then apply configuration:

	make install-gw

By default, this will install:

* /etc/dhcpd.conf
* /etc/pf.vmredirs
* /var/nsd/zones/master/10.in-addr.arpa
* /var/nsd/zones/master/example.org

For the second one, it's assumed you have something like that in your
[/etc/pf.conf](https://man.openbsd.org/pf.conf.5):

	anchor "vmlan" in on egress proto tcp to (egress) {
	        include "/etc/pf.vmredirs"
	}
	pass in on egress tagged VM_SSH rtable 1

It's a good idea to have student VMs running in separate routing domain for safety purposes,
since students have full control over their machines and can send virtually anything to the network.

## Storage

Contains installation sets and answers, and serves them (e.g., over HTTP(S)).
To build those, run:

	make stor

If everything is good, put generated `FOO-install.conf` and `siteXY.tgz`
files in the place they belong:

	make install-stor

By default, this will put OpenBSD installer's answer files into `/instsrc/install`,
and the siteXY.tgz will go into `/instsrc/pub/OpenBSD/X.Y/amd64`; the index.txt
in the latter directory will be regenerated to make `siteXY.tgz` visible.
