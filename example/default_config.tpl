# defaults
!template_suffix=.tpl
!template_dir=.
!zone_suffix=.db
!zone_dir=.
!version_suffix=.ver
!version_dir=.
!header=header.tpl
!footer=footer.tpl
!ttl=1d
!refresh=4h
!retry=1h
!expire=30d
!negttl=15m
!nsname=localhost.
!maintname=root.localhost.
!rrttl=""
!origin="@"
!namedconf = "!zone_dir/named-zones.conf"

!cmd_reload = "rndc reload"
!cmd_checkzone = "/usr/sbin/named-checkzone -i local !zone !zonefile"
!cmd_checkconf = "/usr/sbin/named-checkconf !namedconf"
