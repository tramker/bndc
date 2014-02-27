module gen;

import std.stdio, std.file, std.conv, std.datetime;
import vars, cmds, hosts, eparser;

EParser parser;

/* check if zone template changed */
bool changed(string zone)
{
	string tplfil = var["template_dir"] ~ "/" ~ zone ~ var["template_suffix"];
	string verfil = var["template_dir"] ~ "/" ~ zone ~ var["version_suffix"];

	return timeLastModified(tplfil) > timeLastModified(verfil, SysTime.min);
}

/* generate and remember zone serial number */
string genSerial(string zone)
{
	if (zone.length < 1)
		throw new Exception(__FUNCTION__ ~ "(): missing zone name");
	if (var["version_suffix"].length < 3)
		throw new Exception(__FUNCTION__ ~ "(): version file suffix " ~ var["version_suffix"] ~" not allowed)");
	string verfil = var["template_dir"] ~ "/" ~ zone ~ var["version_suffix"];
	string verstr = "0"; //required when version file missing
	uint newver = to!uint(Clock.currTime.toISOString[0..8] ~ "00"); //new version from clock
	try { verstr = cast(string) std.file.read(verfil, 10); } catch (FileException e) {}
	uint oldver = to!uint(verstr); //old version from file

	if (newver <= oldver)
		newver = oldver + 1;

	verstr = to!string(newver);
	std.file.write(verfil, verstr);
	return verstr;
}

/* !DOMAIN(zone.cz) - generate zone file - arg0: zone, argn: parameters */
string genDomain(string[] args)
{
	debug stderr.writeln("DEBUG genDomain(): ", args);
	if (args.length < 1)
		throw new Exception(__FUNCTION__ ~ "(): missing argument - zone name");
	if (var["zone_suffix"].length < 3)
		throw new Exception(__FUNCTION__ ~ "(): zone file suffix " ~ var["zone_suffix"] ~" not allowed)");
	string zone = args[0];
	var.zone = zone; // dulezite pro vars.get|put a jinde
	scope(exit) var.zone = null;
	string tplfil = var["template_dir"] ~ "/" ~ zone ~ var["template_suffix"];
	string zonfil = var["zone_dir"]     ~ "/" ~ zone ~ var["zone_suffix"];
	bool changed = zone.changed;
	scope(success) { import scanzone; scanZone(hostdb, zone, zonfil, changed); } //z vysledneho souboru nacte hosty do db
	if (! changed)
		return null;

	var["version"] = genSerial(zone);

	string bdy = cast(string) read(tplfil, MAXSIZE);
	auto pbdy = parser.parse(Element(Element.Type.FILE, bdy)).data;

	string hdr = cast(string) read(var["template_dir"] ~ "/" ~ var["header"], MAXSIZE);
	auto phdr = parser.parse(Element(Element.Type.FILE, hdr)).data;

	string ftr = cast(string) read(var["template_dir"] ~ "/" ~ var["footer"], MAXSIZE);
	auto pftr = parser.parse(Element(Element.Type.FILE, ftr)).data;

	debug stderr.writeln("DEBUG =========== ", args[0], " ===========");
	debug stderr.writeln("DEBUG genDomain(): writing zone to file ", zonfil);
	auto zf = File(zonfil, "w");
	zf.write(phdr ~ "\n" ~ pbdy ~ "\n" ~ pftr);
	
	return null;
}

/* !REVERSE(11.12.13) #hleda 13.12.11.in-addr.arpa.tpl */
string genReverse(string args[])
{
	import std.algorithm, std.string;
	debug stderr.writeln("DEBUG genReverse(): ", args);
	if (args.length < 1)
		throw new Exception(__FUNCTION__ ~ "(): missing argument - ip address");
	if (var["zone_suffix"].length < 3)
		throw new Exception(__FUNCTION__ ~ "(): zone file suffix " ~ var["zone_suffix"] ~" not allowed)");
	string zone = IPv4(args[0]).toReverseZone;
	var.zone = zone; // dulezite pro vars.get|put a jinde
	scope(exit) var.zone = null;
	string tplfil = var["template_dir"] ~ "/" ~ zone ~ var["template_suffix"];
	string zonfil = var["zone_dir"]     ~ "/" ~ zone ~ var["zone_suffix"];
	var["ipnetwork"] = args[0]; // pouziva cmdPTR
	scope(exit) var.remove("ipnetwork");

	auto chdb = hostdb.filterIPv4!(FilterOpt.CHANGED)(args[0]); //db changed only
	debug stderr.writefln("changed: file: %s, db: %s: ", zone.changed, chdb.count);
	if (!zone.changed && !chdb.count) // file not changed and db not changed
		return null;

	var["version"] = genSerial(zone);

	string bdy = cast(string) read(tplfil, MAXSIZE);
	auto pbdy = parser.parse(Element(Element.Type.FILE, bdy)).data;

	string hdr = cast(string) read(var["template_dir"] ~ "/" ~ var["header"], MAXSIZE);
	auto phdr = parser.parse(Element(Element.Type.FILE, hdr)).data;

	string ftr = cast(string) read(var["template_dir"] ~ "/" ~ var["footer"], MAXSIZE);
	auto pftr = parser.parse(Element(Element.Type.FILE, ftr)).data;

	auto ipdb = hostdb.filterIPv4(args[0]); //db changed & unchanged
	debug foreach (f; ipdb) stderr.writeln(f);

	foreach (addr4; ipdb)
	{
		pbdy ~= format("%s\t\tPTR\t%s\n", addr4.ad.toReverseHost(args[0]), hostdb[addr4.ad].hns[0].hn);
	}

	debug stderr.writeln("DEBUG =========== ", args[0], " ===========");
	debug stderr.writeln("DEBUG genReverse(): writing zone to file ", zonfil);
	auto zf = File(zonfil, "w");
	zf.write(phdr ~ "\n" ~ pbdy ~ "\n" ~ pftr);

	return null;
}

/* arg0: ip addr (konec), arg1: hostname (FQDN) */
string cmdPTR(string[] args)
{
	string ipaddr = var["ipnetwork"] ~ "." ~ args[0];
	string hostname = args[1];
	debug stderr.writefln("DEBUG cmdPTR: host: %s, ip: %s", hostname, ipaddr);
	auto db = hostdb.filterIPv4(ipaddr);
	if (db.empty)
		hostdb.add4(hostname, ipaddr, true);
	else
	{
		assert(db.front.ad == IPv4(ipaddr));
		auto oldhosts = db.front.hns;
		db.front.hns.length++;
		db.front.hns[0] = new Host(hostname, true);
		db.front.hns[1..$] = oldhosts;
	}
	return null;
}
