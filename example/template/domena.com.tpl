# let's set some zone specific vars first
!maintname = my.email.com. !ttl = 2d

!NS(machine, ns.someisp.net.)
!MX(10 mail, 20 backup.someisp.net.)

; this comment goes to the zone file
!A(machine, 11.12.13.1)
!A(machine, 11.12.13.2) # second IP
!rrttl=12h				# lower RR TTL from now
!CNAME(mail)
!rrttl=""				# back to zone default RR TTL
machine		IN 		TXT	"this is our server"

# subdomain
$ORIGIN sub ; origin:!origin zone:!zone
!NS(machine.!zone., ns2.someisp.net.)
!A(mypc, 11.12.13.30)
# back to our domain
$ORIGIN !zone. ; origin:!origin zone:!zone

!H(other.domain.org.)
!CNAME(one, two)
