/* nacte zonovy soubor a ulozi do databaze hosts a jejich ip adresy */
/* jednoducha naivni implementace - melo vy se predelat na komplet parser dle RFC 1035 */
module scanzone;
import std.stdio, std.regex;
import hosts, zones;

auto RE_ORIGIN = regex(r"^\s*\$ORIGIN\s+([a-z0-9.-]+)","i");
auto RE_HOST = regex(r"^([a-z0-9@*.-]*)\s+[0-9dmhsIN\s]*(A|AAAA)\s+([0-9a-f.:]{4,})","i");

void scanZone(ref Hostdb db, Zone zone, bool changed=true)
{
	//debug stderr.writefln("DEBUG scanzone(%s): %s ", zone, changed);
	auto file = File(zone.zonfil);
	origin = zone.name ~ ".";
	lastname = origin.idup;
	foreach (line; file.byLine())
	{
		if (auto m = matchFirst(line, RE_ORIGIN))
			origin = m.captures[1].idup;
		else
		if (auto m = matchFirst(line, RE_HOST))
			addToDB(db, m.captures[1].idup, m.captures[2].idup, m.captures[3].idup, changed);
	}
}

private:

string origin;
string lastname;

/* parametry jsou buffer z match, neukladat */ 
void addToDB(ref Hostdb db, string name, string rr, string data, bool changed)
{
	import std.string;
	string hostname;

	//debug stderr.writef("scanzone: %s, %s, %s, %s  =>  ", origin, name, rr, data);
	//debug scope(success) stderr.writeln(hostname);

	if (name.length)
		lastname = name;
	else
		name = lastname;

	if (name == "@")
		hostname = origin;
	else if (name[$-1] == '.')
		hostname = name;
	else
		hostname = name ~ "." ~ origin;
	final switch(rr.toUpper)
	{
		case "A":	 db.add4(hostname, data, changed); break;
		case "AAAA": db.add6(hostname, data, changed); break;
	}
}

unittest
{
	import std.file, std.algorithm, std.range;
	Hostdb testdb;
	
	string input =
`
$TTL 2d
$ORIGIN		testunit.cz.
@       SOA bid.iline.cz. mk.krej.cz. (2014022100 4h 1h 30d 15m)
@       NS  stroj
@       MX  10 mail.iline.cz.
			A	11.12.13.100
stroj       A   11.12.13.10
  15m IN	A	11.12.14.10 ; TTL ignored, stroj jiz ma nastavene TTL
;stroj      A   11.12.13.11
 rrtype     A   11.12.13.11 ; ERROR, mezera nazacatku, takze to neni hostname !
jedna 12h A 11.12.13.1
dva.testunit.cz. 6h A   11.12.13.2
@       A   192.168.254.136
$ORIGIN test.testunit.cz.
tri-3 A 150.16.0.10
jedna		IN	A	11.12.13.1
knedlik     IN  TXT  "toto  A  1.2.3.4"
`;

	auto file = File("scanzone_unittest.tmp.db", "w");
	file.write(input);
	file.close;
	
	scope testzone = new Zone("testunit.cz", "scanzone_unittest.tmp");
	scanZone(testdb, testzone);
	remove("scanzone_unittest.tmp.db");
	//debug writeln(testdb);
	assert(testdb.filterHost!"true"().count == 6);
	assert(testdb.filterIPv4!"true"().count == 7);
	assert(testdb.filterHost("stroj.testunit.cz.").front.i4s.length == 2);
	assert(testdb["stroj.testunit.cz."].i4s.length == 2);
	assert(testdb.filterHost("dva.testunit.cz.").front.i4s[0].ad == IPv4("11.12.13.2"));
	assert(testdb["dva.testunit.cz."].i4s[0].ad == IPv4("11.12.13.2"));
	assert(testdb.filterHost!(a => a.hn=="testunit.cz.")().front.i4s[1].ad == IPv4("192.168.254.136/32")); //pouze host testunit.cz.
	assert(testdb["testunit.cz."].i4s[1].ad == IPv4("192.168.254.136/32"));
	assert(testdb.filterIPv4("11.12.13.1/32").front.hns.length == 2);
	assert(testdb[IPv4("11.12.13.1/32")].hns.length == 2);
	assert(testdb.filterIPv4("150.16.0.10/32").front.hns[0].hn == "tri-3.test.testunit.cz.");
	assert(testdb[IPv4("150.16.0.10")].hns[0].hn == "tri-3.test.testunit.cz.");
}
