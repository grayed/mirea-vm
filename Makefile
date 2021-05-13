.if exists(${.CURDIR}/local.conf)
. include <${.CURDIR}/local.conf>
.endif

LOGIN_PREFIX ?=		st
LOGIN_SUFFIX ?=

DHCPD_CONF_FILE ?=	/etc/dhcpd.conf
MAC_PREFIX ?=		0a:00:

DNS_FORW_ZONE ?=	mirea.lan
IPV4_PREFIX ?=		10.0.0.0/8
IPV6_PREFIX ?=		fc00::/48
DNS_ZONES_DIR ?=	/var/nsd/zones/master

PF_REDIR_FILE ?=	/etc/pf.vmredirs
PF_TAG ?=		VM_SSH
PF_PORT_BASE ?=		22000

INST_ROOT ?=		/instsrc
INST_CONF_DIR ?=	${INST_ROOT}/install
INST_RELEASE ?=		6.8
INST_ARCH ?=		amd64

TFTP_DIR ?=		/tftpboot

# end of customizable variables

GROUPS !=		cd ${.CURDIR}/groups; ls *.group | sed -e 's/\.group$$//'
.if empty(GROUPS)
.BEGIN:
	@echo WARNING: no student groups found
.endif

IPV4_PREFIX_LEN =	${IPV4_PREFIX:C,.*/,,}
IPV6_PREFIX_LEN =	${IPV6_PREFIX:C,.*/,,}

# XXX hack to avoid extraneous "ipv6calc not found" on storage nodes
.ifmake gw || install-gw || install-dns
DNS_REV4_ZONE !=	ipv6calc -q -O revipv4 ${IPV4_PREFIX} | sed 's/.$$//'
DNS_REV6_ZONE !=	ipv6calc -q -O revnibbles.arpa ${IPV6_PREFIX} | sed 's/.$$//'
.else
DNS_REV4_ZONE =	foo
DNS_REV6_ZONE =	bar
.endif

DNS_FORW_ZONE_FILE =	${DNS_ZONES_DIR}/${DNS_FORW_ZONE}
DNS_REV4_ZONE_FILE =	${DNS_ZONES_DIR}/${DNS_REV4_ZONE}
DNS_REV6_ZONE_FILE =	${DNS_ZONES_DIR}/${DNS_REV6_ZONE}

INST_DIST_DIR =		${INST_ROOT}/pub/OpenBSD/${INST_RELEASE}/${INST_ARCH}
INST_ANSWERS_COOKIE =	inst-answers.${INST_RELEASE}.${INST_ARCH}.cookie
INST_ANSWERS_TEMPLATE =	templates/install-${INST_RELEASE}-${INST_ARCH}.conf.in
INST_SITE_TGZ =		site${INST_RELEASE:C/\.//}-${INST_ARCH}.tgz

GENERATED_FILES_gw =	dhcpd.conf pf.vmredirs dns_${DNS_FORW_ZONE}
GENERATED_FILES_gw +=	dns_${DNS_REV4_ZONE} dns_${DNS_REV6_ZONE}
GENERATED_FILES_stor =	${INST_ANSWERS_COOKIE} ${INST_SITE_TGZ}
GENERATED_FILES =	${GENERATED_FILES_gw} ${GENERATED_FILES_stor}

INST_SITE_TGZ_DEPS !=	find ${.CURDIR}/site

INVERT_IPV6 = sed 's/./&./g' | awk -v RS=. // | tail -r \
	| awk -v ORS= '{print "." $$0}'

.PHONY: all clean
.PHONY: gw install-gw install-dhcpd install-dns install-pf
.PHONY: stor install-stor install-answers install-site install-tftp

all:
	@echo please use either 'make gw' or 'make stor' >&2
	@false

clean:
	rm -f ${GENERATED_FILES}

gw: dhcpd.conf dns_${DNS_FORW_ZONE} dns_${DNS_REV4_ZONE} dns_${DNS_REV6_ZONE} pf.vmredirs

stor: ${INST_ANSWERS_COOKIE} ${INST_SITE_TGZ} check-tftp

install-gw: install-pf install-dhcpd install-dns
install-stor: check-tftp install-answers install-site

install-answers:

install-dhcpd:
	install -o root -g wheel -m 0644 dhcpd.conf ${DHCPD_CONF_FILE}
	rcctl restart dhcpd

install-dns:
	install -o root -g wheel -m 0644 dns_${DNS_REV6_ZONE} ${DNS_REV6_ZONE_FILE}
	nsd-control reload ${DNS_REV6_ZONE}
	install -o root -g wheel -m 0644 dns_${DNS_REV4_ZONE} ${DNS_REV4_ZONE_FILE}
	nsd-control reload ${DNS_REV4_ZONE}
	install -o root -g wheel -m 0644 dns_${DNS_FORW_ZONE} ${DNS_FORW_ZONE_FILE}
	nsd-control reload ${DNS_FORW_ZONE}

install-pf:
	install -o root -g wheel -m 0640 pf.vmredirs ${PF_REDIR_FILE}
	pfctl -f /etc/pf.conf

install-site:
	install ${INST_SITE_TGZ} ${INST_DIST_DIR}/site${INST_RELEASE:C/\.//}.tgz
	cd ${INST_DIST_DIR}; ls -l >index.txt

install-tftp:
	install -d -o root -g wheel -m 0755 ${TFTP_DIR}
	install -o root -g wheel -m 0444 ${INST_DIST_DIR}/bsd.rd ${TFTP_DIR}/bsd
	install -o root -g wheel -m 0444 ${INST_DIST_DIR}/pxeboot ${TFTP_DIR}/
	ln -sf pxeboot ${TFTP_DIR}/auto_install
	ln -sf pxeboot ${TFTP_DIR}/auto_upgrade

check-tftp: .SILENT .IGNORE
	( { cd ${INST_DIST_DIR}; sha256 -qC SHA256 bsd.rd pxeboot; } || \
	{ echo "WARNING: bsd.rd and/or pxeboot are not downloaded yet, ${.MAKE} install-tftp is not available" >&2; false; } ) && \
	( test -e ${TFTP_DIR}/bsd -a -e ${TFTP_DIR}/auto_install -a -e ${TFTP_DIR}/auto_upgrade -a -e ${TFTP_DIR}/pxeboot || \
	{ echo "WARNING: TFTP directory is not filled yet, you may wish to run ${.MAKE} install-tftp" >&2; false; } ) && \
	( cmp -s "${INST_DIST_DIR}/bsd.rd" "${TFTP_DIR}/bsd" || \
	{ echo "WARNING: ${INST_DIST_DIR}/bsd.rd  differs from ${TFTP_DIR}/bsd;     need to run ${.MAKE} install-tftp" >&2; false; }; \
	  cmp -s "${INST_DIST_DIR}/pxeboot" "${TFTP_DIR}/pxeboot" || \
	{ echo "WARNING: ${INST_DIST_DIR}/pxeboot differs from ${TFTP_DIR}/pxeboot; need to run ${.MAKE} install-tftp" >&2; false; } )

dhcpd.conf: gen-dhcpd-head
gen-dhcpd-head: .USE templates/dhcpd.conf.head
	cat ${.CURDIR}/templates/dhcpd.conf.head >$@

dns_${DNS_FORW_ZONE}: gen-dns-head templates/dns_${DNS_FORW_ZONE}.head
dns_${DNS_REV4_ZONE}: gen-dns-head templates/dns_${DNS_REV4_ZONE}.head
dns_${DNS_REV6_ZONE}: gen-dns-head templates/dns_${DNS_REV6_ZONE}.head
gen-dns-head: .USE
	@grep -q '%TIMESTAMP%' "${.CURDIR}/templates/${@:C,.*/dns_,,}.head" || \
	    { echo "${@:C,.*/dns_,,}.head misses %TIMESTAMP% marker" >&2; false; }
	@echo "${IPV4_PREFIX}" | \
	    grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' || \
	    { echo "invalid IPv4 prefix"; false; }
	@echo "${IPV6_PREFIX}" | grep -Eiqx '[0-9a-f:]+[0-9a-f]::/[0-9]+' || \
	    { echo "invalid IPv6 prefix"; false; }
	@test 8 = "${IPV4_PREFIX_LEN}" || \
	    { echo "only /8 IPv4 prefixes are supported" >&2; false; }
	@test 16 -le "${IPV6_PREFIX_LEN}" -a 96 -ge "${IPV6_PREFIX_LEN}" || \
	    { echo "only /16 to /96 IPv6 prefixes are supported" >&2; false; }
	@test 0 -eq $$((${IPV6_PREFIX_LEN} % 16)) || \
	    { echo "IPv6 prefix length be a multiple of 16" >&2; false; }

	try=01; date=`date +%Y%m%d`; \
	while grep -qw $$date$$try ${DNS_ZONES_DIR}/${@:C/^dns_//}; do \
		try=`printf %02d $$(($$try + 1))`; \
	done; \
	sed "s/%TIMESTAMP%/$$date$$try/g" \
	    "${.CURDIR}/templates/${@:C,.*/dns_,,}.head" >$@

.if exists(templates/pf.vmredirs.head)
pf.vmredirs: gen-pf-redir-head templates/pf.vmredirs.head
gen-pf-redir-head: .USE
	cat ${.CURDIR}/templates/pf.vmredirs.head >$@
.else
pf.vmredirs: gen-pf-redir-head
gen-pf-redir-head: .USE
	echo -n >$@
.endif

${INST_SITE_TGZ}: ${INST_SITE_TGZ_DEPS}
	(cd ${.CURDIR}/site; pax -wz install.site etc/*) >$@


.for g in ${GROUPS}
$g_flow =	${g:C/_.*//}
$g_year =	${g:C/.*_(.*)_.*/\1/}
$g_gnum =	${g:C/.*_//}

$g_flowcode =	$$(grep -Fnx "${$g_flow}" ${.CURDIR}/groups/flows.list | sed 's/:.*//')
$g_code =	${$g_flowcode}${$g_gnum}

$g_input =	${.CURDIR}/groups/$g.group
$g_nums !=	cut -c 1-3 <${$g_input}

$g_host_base =	${$g_flow}-${$g_year}-${$g_gnum}-

$g_mac_base !=	printf "%s%02d:%02d:%02d:" \
	${MAC_PREFIX} ${$g_flowcode} ${$g_year} ${$g_gnum}

$g_ip4_base !=	printf "%s.%d.%d." \
	${IPV4_PREFIX:C/\..*//} ${$g_code} ${$g_year}
$g_rev4_sufx =	.${$g_year}.${$g_code}

$g_ip6_base !=	printf %s:%02d%02d:%02d ${IPV6_PREFIX:C,::/.*,,} \
	   ${$g_flowcode} ${$g_year} ${$g_gnum}
$g_rev6_sufx !=	printf "%02d%02d%02d" ${$g_year} ${$g_gnum} ${$g_flowcode} | \
	${INVERT_IPV6}
$g_rev6_prfx != \
	cnt=$$(( (128 - ${IPV6_PREFIX_LEN}) / 4 - 8)); \
	jot -b 0. -s '' $$cnt

GENERATED_FILES_$g =	${$g_nums:%=${$g_host_base}%-install.conf}
GENERATED_FILES +=	${GENERATED_FILES_$g}

${GENERATED_FILES}: ${$g_input}

.for n in ${$g_nums}
${INST_ANSWERS_COOKIE}: ${$g_host_base}$n-install.conf
${$g_host_base}$n-install.conf: ${INST_ANSWERS_TEMPLATE}
	grep '^[[:space:]]*$n[[:space:]]' ${$g_input} | { \
	read junk login pass name; \
	sed -e "s,%ST_LOGIN%,$$login,g" \
	    -e "s,%ST_NAME%,$$name,g" \
	    -e "s,%ST_PASS%,$$pass,g" \
	    <${.CURDIR}/${INST_ANSWERS_TEMPLATE} >$@; \
	}

.PHONY: install-${$g_host_base}$n-install.conf
install-answers: install-${$g_host_base}$n-install.conf
install-${$g_host_base}$n-install.conf:
	install ${$g_host_base}$n-install.conf ${INST_CONF_DIR}/
.endfor

dhcpd.conf: gen-dhcpd-$g
gen-dhcpd-$g: .USE
	echo >>$@
	while read -r n junk; do \
		printf "host %s%-2d { hardware ethernet %s%02d; fixed-address %s%d; }\n" \
		       "${$g_host_base}" "$$n" \
		       "${$g_mac_base}" "$$n" \
		       "${$g_ip4_base}" "$$n"; \
	done <${$g_input} >>$@;

dns_${DNS_FORW_ZONE}: gen-forward-dns-$g
gen-forward-dns-$g: .USE
	echo >>$@
	while read -r n junk; do \
		printf "%s%d\tA\t%s%d\n" \
		       "${$g_host_base}" "$$n" \
		       "${$g_ip4_base}"  "$$n"; \
		printf "%s%d\tAAAA\t%s%02d::\n" \
		       "${$g_host_base}" "$$n" \
		       "${$g_ip6_base}"  "$$n"; \
	done <${$g_input} >>$@

dns_${DNS_REV4_ZONE}: gen-rev4-dns-$g
gen-rev4-dns-$g: .USE
	echo >>$@
	while read -r n junk; do \
		printf "%s%s\tPTR\t%s%d.%s.\n" \
		       "$$n" "${$g_rev4_sufx}" \
		       "${$g_host_base}" "$$n" "${DNS_FORW_ZONE}"; \
	done <${$g_input} >>$@

dns_${DNS_REV6_ZONE}: gen-rev6-dns-$g
gen-rev6-dns-$g: .USE
	echo >>$@
	while read -r n junk; do \
		ip6n=$$(printf %02d $$n | ${INVERT_IPV6} | sed 's/^.//'); \
		printf "%s%s%s\tPTR\t%s%d.%s.\n" \
		       "${$g_rev6_prfx}" "$$ip6n" "${$g_rev6_sufx}" \
		       "${$g_host_base}" "$$n" "${DNS_FORW_ZONE}"; \
	done <${$g_input} >>$@

pf.vmredirs: gen-pf-redir-$g
gen-pf-redir-$g: .USE
	echo >>$@
	while read -r n login junk; do \
		uid=$$login; \
		test -z "${LOGIN_PREFIX}" || uid=$${uid#${LOGIN_PREFIX}}; \
		test -z "${LOGIN_SUFFIX}" || uid=$${uid%${LOGIN_SUFFIX}}; \
		port=$$((${PF_PORT_BASE} + $$uid)); \
		printf "match in log inet  proto tcp to port %d rdr-to %s%d port ssh tag %s\n" \
		       $$port ${$g_ip4_base} $$n ${PF_TAG}; \
		printf "match in log inet6 proto tcp to port %d rdr-to %s%02d:: port ssh tag %s\n" \
		       $$port ${$g_ip6_base} $$n ${PF_TAG}; \
	done <${$g_input} >>$@

.endfor

${GENERATED_FILES}: Makefile

dhcpd.conf: gen-dhcpd-tail
gen-dhcpd-tail: .USE templates/dhcpd.conf.tail
	cat ${.CURDIR}/templates/dhcpd.conf.tail >>$@

.if exists(templates/pf.vmredirs.tail)
pf.vmredirs: gen-pf-redir-tail templates/pf.vmredirs.tail
gen-pf-redir-tail: .USE
	cat ${.CURDIR}/templates/pf.vmredirs.tail >>$@
.endif
