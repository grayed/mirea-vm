.if exists(${.CURDIR}/local.conf)
. include <${.CURDIR}/local.conf>
.endif

LOGIN_PREFIX ?=		st

DHCPD_CONF_FILE ?=	/etc/dhcpd.conf

DNS_FORW_ZONE ?=	example.org.
DNS_REV_ZONE ?=		10.in-addr.arpa
DNS_ZONES_DIR ?=	/var/nsd/zones/master

PF_REDIR_FILE ?=	/etc/pf.vmredirs
PF_TAG ?=		VM_SSH
PF_PORT_BASE ?=		22000

INST_CONF_DIR ?=	/instsrc/install
INST_RELEASE ?=		6.8
INST_ARCH ?=		amd64
INST_DIST_DIR ?=	/instsrc/pub/OpenBSD/${INST_RELEASE}/${INST_ARCH}

# end of customizable variables

GROUPS !=		cd ${.CURDIR}/groups; ls *.group | sed -e 's/\.group$$//'

DNS_FORW_ZONE_FILE =	${DNS_ZONES_DIR}/${DNS_FORW_ZONE}
DNS_REV_ZONE_FILE =	${DNS_ZONES_DIR}/10.in-addr.arpa

INST_ANSWERS_COOKIE =	inst-answers.${INST_RELEASE}.${INST_ARCH}.cookie
INST_ANSWERS_TEMPLATE =	templates/install-${INST_RELEASE}-${INST_ARCH}.conf.in
INST_SITE_TGZ =		site${INST_RELEASE:C/\.//}-${INST_ARCH}.tgz

GENERATED_FILES_gw =	dhcpd.conf dns_${DNS_FORW_ZONE} dns_${DNS_REV_ZONE} pf.vmredirs
GENERATED_FILES_stor =	${INST_ANSWERS_COOKIE} ${INST_SITE_TGZ}
GENERATED_FILES =	${GENERATED_FILES_gw} ${GENERATED_FILES_stor}

INST_SITE_TGZ_DEPS !=	find ${.CURDIR}/site

.PHONY: all clean
.PHONY: gw install-gw install-dhcpd install-dns install-pf
.PHONY: stor install-stor install-answers install-site

all:
	@echo please use either 'make gw' or 'make stor' >&2
	@false

clean:
	rm -f ${GENERATED_FILES}

gw: dhcpd.conf dns_${DNS_FORW_ZONE} dns_${DNS_REV_ZONE} pf.vmredirs

stor: ${INST_ANSWERS_COOKIE} ${INST_SITE_TGZ}

install-gw: install-pf install-dhcpd install-dns
install-stor: install-answers install-site

install-answers:

install-dhcpd:
	install -o root -g wheel -m 0644 dhcpd.conf ${DHCPD_CONF_FILE}
	rcctl restart dhcpd

install-dns:
	install -o root -g wheel -m 0644 dns_${DNS_FORW_ZONE} ${DNS_FORW_ZONE_FILE}
	nsd-control reload ${DNS_FORW_ZONE}
	install -o root -g wheel -m 0644 dns_${DNS_REV_ZONE} ${DNS_REV_ZONE_FILE}
	nsd-control reload ${DNS_REV_ZONE}

install-pf:
	install -o root -g wheel -m 0640 pf.vmredirs ${PF_REDIR_FILE}
	pfctl -f /etc/pf.conf

install-site:
	install ${INST_SITE_TGZ} ${INST_DIST_DIR}/site${INST_RELEASE:C/\.//}.tgz
	cd ${INST_DIST_DIR}; ls -l >index.txt


dhcpd.conf: gen-dhcpd-head
gen-dhcpd-head: .USE templates/dhcpd.conf.head
	cat ${.CURDIR}/templates/dhcpd.conf.head >$@

dns_${DNS_FORW_ZONE}: gen-dns-head templates/dns_${DNS_FORW_ZONE}.head
dns_${DNS_REV_ZONE}:  gen-dns-head templates/dns_${DNS_REV_ZONE}.head
gen-dns-head: .USE
	@grep -q '%TIMESTAMP%' "${.CURDIR}/templates/${@:C,.*/dns_,,}.head" || \
	    { echo "${@:C,.*/dns_,,}.head misses %TIMESTAMP% marker" >&2; false; }
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

$g_input =	${.CURDIR}/groups/$g.group
$g_nums !=	cut -c 1-3 <${$g_input}

$g_bases !=	${.CURDIR}/calc_group_bases ${$g_flow} ${$g_year} ${$g_gnum}
$g_mac_base =	${$g_bases:M*\:*\:*\:*\:*\:}
$g_ip_base =	${$g_bases:M*.*.*.}
$g_revdns_sfx =	${$g_bases:M.*.*}
$g_host_base =	${$g_flow}-${$g_year}-${$g_gnum}-

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
		printf "host %s%d { hardware ethernet %s%02d; fixed-address %s%d; }\n" \
		       "${$g_host_base}" "$$n" \
		       "${$g_mac_base}" "$$n" \
		       "${$g_ip_base}" "$$n"; \
	done <${$g_input} >>$@;

dns_${DNS_FORW_ZONE}: gen-forward-dns-$g
gen-forward-dns-$g: .USE
	echo >>$@
	while read -r n junk; do \
		printf "%s%d\tA\t%s%d\n" \
		       "${$g_host_base}" "$$n" \
		       "${$g_ip_base}" "$$n"; \
	done <${$g_input} >>$@

dns_${DNS_REV_ZONE}: gen-reverse-dns-$g
gen-reverse-dns-$g: .USE
	echo >>$@
	while read -r n junk; do \
		printf "%s%s\tPTR\t%s%d.%s.\n" \
		       "$$n" "${$g_revdns_sfx}" \
		       "${$g_host_base}" "$$n" "${DNS_FORW_ZONE}"; \
	done <${$g_input} >>$@

pf.vmredirs: gen-pf-redir-$g
gen-pf-redir-$g: .USE
	echo >>$@
	while read -r n login junk; do \
		uid=$${login#${LOGIN_PREFIX}}; \
		port=$$((${PF_PORT_BASE} + $$uid)); \
		printf "match in log proto tcp to port %d rdr-to %s%d port ssh tag %s\n" \
		       $$port ${$g_ip_base} $$n ${PF_TAG}; \
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
