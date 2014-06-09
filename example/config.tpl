# master template for bndc
# !var=something - set variable !var to "something"
# !CMD(domain.com) - run command !CMD with argument "domain.com"
# system sets variables !zone, !zonefile, !host
# everything not recognized goes to the zone without changes

!template_dir=template
!zone_dir=zone
!version_dir=zone
!ttl=1d
!refresh=4h
!retry=1h
!expire=30d
!negttl=5m
!nsname = `echo `hostname -f`.`
!maintname=root.!nsname
!namedconf = "!zone_dir/named-zones.conf"

!cmd_reload = "rndc reload"
!cmd_checkzone = "/usr/sbin/named-checkzone -i local !zone !zonefile"
!cmd_checkconf = "/usr/sbin/named-checkconf !namedconf"

!DOMAIN(domena.com)
#!DOMAIN(domena.com, also-notify {10.10.10.1;})
!REVERSE(11.12.13) # 13.12.11.in-addr.arpa.tpl
