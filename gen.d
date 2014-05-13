module gen;

import std.stdio, std.file, std.conv, std.datetime;
import vars, cmds, hosts, eparser;
static import globals;

EParser parser;
int errcount;
int changecount;
string namedcontent;

/* check if zone template changed */
bool changed(string zone)
{
	string tplfil = var["template_dir"] ~ "/" ~ zone ~ var["template_suffix"];
	string verfil = var["version_dir"] ~ "/" ~ zone ~ var["version_suffix"];

	return timeLastModified(tplfil) > timeLastModified(verfil, SysTime.min);
}

/* generate and remember zone serial number */
string genSerial(string zone)
{
	if (zone.length < 1)
		throw new Exception(__FUNCTION__ ~ "(): missing zone name");
	if (var["version_suffix"].length < 3)
		throw new Exception(__FUNCTION__ ~ "(): version file suffix " ~ var["version_suffix"] ~" not allowed)");
	string verfil = var["version_dir"] ~ "/" ~ zone ~ var["version_suffix"];
	string verstr = "0"; //required when version file missing
	uint newver = to!uint(Clock.currTime.toISOString[0..8] ~ "00"); //new version from clock
	try { verstr = cast(string) std.file.read(verfil, 10); } catch (FileException e) {}
	uint oldver = to!uint(verstr); //old version from file

	if (newver <= oldver)
		newver = oldver + 1;

	verstr = to!string(newver);
	try { std.file.write(verfil, verstr); } catch (FileException e) { stderr.writeln("Error writing ", e.msg); }
	return verstr;
}

/* !DOMAIN(zone.cz) a !REVERSE(11.12.13) - generate zone file - arg0: zone, argn: parameters */
string genZone(string KIND="forward")(string[] args)
in { static assert(KIND=="forward" || KIND=="reverse"); }
body {
	enum Kind:string { FWD="forward", REV="reverse" }

	import std.algorithm, std.string;
	debug stderr.writeln("DEBUG genZone(): ", args);
	if (args.length < 1)
	{
		static if (KIND==Kind.FWD)
				throw new Exception(__FUNCTION__ ~ "(): missing argument - zone name");
		else static if (KIND==Kind.REV)
				throw new Exception(__FUNCTION__ ~ "(): missing argument - ip address");
	}
	if (var["zone_suffix"].length < 3)
		throw new Exception(__FUNCTION__ ~ "(): zone file suffix " ~ var["zone_suffix"] ~" not allowed)");

	string[] extras;
	if (args.length == 2)
		extras = args[1..$];
	static if (KIND==Kind.FWD)		string zone = args[0];
	else static if (KIND==Kind.REV) string zone = IPv4(args[0]).toReverseZone;
	var.zone = zone; // dulezite pro vars.get|put a jinde
	scope(exit) var.zone = null;
	string tplfil = var["template_dir"] ~ "/" ~ zone ~ var["template_suffix"];
	string zonfil = var["zone_dir"]     ~ "/" ~ zone ~ var["zone_suffix"];
	var["zonefile"] = zonfil;
	static if (KIND==Kind.FWD)
	{
		addToNamedConf(zone, extras);
		bool changed = zone.changed;
		scope(success) { import scanzone; scanZone(hostdb, zone, zonfil, changed); } //z vysledneho souboru nacte hosty do db
		if (! changed)
			return null;
	} else
	static if (KIND==Kind.REV)
	{
		var["ipnetwork"] = args[0]; // pouziva cmdPTR
		scope(exit) var.remove("ipnetwork");
		addToNamedConf(zone, extras);
		auto chdb = hostdb.filterIPv4!(FilterOpt.CHANGED)(args[0]); //db changed only
		//debug stderr.writefln("   changed: file: %s, db: %s: ", zone.changed, chdb.count);
		if (!zone.changed && !chdb.count) // file not changed and db not changed
			return null;
	}

	var["version"] = genSerial(zone);
	var["rrttl"] = "";

	string bdy = cast(string) read(tplfil, globals.MAXSIZE);
	auto pbdy = parser.parse(Element(Element.Type.FILE, bdy)).data;

	string hdr = cast(string) read(var["template_dir"] ~ "/" ~ var["header"], globals.MAXSIZE);
	auto phdr = parser.parse(Element(Element.Type.FILE, hdr)).data;

	string ftr = cast(string) read(var["template_dir"] ~ "/" ~ var["footer"], globals.MAXSIZE);
	auto pftr = parser.parse(Element(Element.Type.FILE, ftr)).data;

	static if (KIND==Kind.REV)
	{
		auto ipdb = hostdb.filterIPv4(args[0]); //db changed & unchanged
		//debug foreach (f; ipdb) stderr.writeln(f);

		foreach (addr4; ipdb)
		{
			pbdy ~= format("%s\t%s\tPTR\t%s\n", addr4.ad.toReverseHost(args[0]), var["rrttl"], hostdb[addr4.ad].hns[0].hn);
		}
	}

	debug stderr.writeln("DEBUG =========== ", zone, " ===========");
	debug stderr.writeln("DEBUG genZone(): writing zone to file ", zonfil);
	auto zf = File(zonfil, "w");
	zf.write(phdr ~ "\n" ~ pbdy ~ "\n" ~ pftr);
	zf.close;
	if (! runCheckZone())
		changecount++;

	return null;
}

/* arg0: ip addr (konec), arg1: hostname (FQDN) */
string cmdPTR(string[] args)
{
	string ipaddr;
	if (var["ipnetwork"].length)
		ipaddr = var["ipnetwork"] ~ "." ~ args[0];
	else
		ipaddr = args[0];
	string hostname = args[1];
	debug stderr.writefln("DEBUG cmdPTR: host: %s, ip: %s", hostname, ipaddr);
	auto db = hostdb.filterIPv4(ipaddr);
	if (db.empty)
		hostdb.add4(hostname, ipaddr, true);
	else
	{
		assert(db.front.ad == IPv4(ipaddr));
		auto oldhosts = db.front.hns;
		db.front.hns.length = 0;
		db.front.hns ~= new Host(hostname, true); //concat nutny, jinak overlapping arrays
		db.front.hns ~= oldhosts;
	}
	return null;
}

int runCheckZone()
{
	import std.process, std.array;
	auto cmdline = parser.parse(Element(Element.Type.LINE, var["cmd_checkzone"])).data;
	auto result = execute(cmdline.split);
	if (result.status)
	{
		stderr.writef("Error checking zone file %s:\n%s", var["zonefile"], result.output);
		errcount++;
	} else stdout.writefln("Zone file %s check OK", var["zonefile"]);
	return result.status;
}

int runCheckConf()
{
	import std.process, std.array;
	auto cmdline = parser.parse(Element(Element.Type.LINE, var["cmd_checkconf"])).data;
	auto result = execute(cmdline.split);
	if (result.status)
	{
		stderr.writef("Error checking config file %s:\n%s", var["namedconf"], result.output);
		errcount++;
	} else stdout.writefln("Config file %s check OK", var["namedconf"]);
	return result.status;
}

int runReload()
{
	import std.process, std.array;
	auto cmdline = parser.parse(Element(Element.Type.LINE, var["cmd_reload"])).data;
	auto result = execute(cmdline.split);
	if (result.status)
	{
		stderr.writef("Error running reload command '%s':\n%s", var["cmd_reload"], result.output);
	} else stdout.write("Reload result: ", result.output);
	return result.status;
}

void addToNamedConf(string zone, string[] extras=null)
{
	import std.string, std.path;
	string content = "zone \"%s\" in {\n\ttype master;\n\tfile \"%s\";%s\n};\n";
	string extra;
	foreach (e; extras)
		extra ~= "\n\t" ~ e ~ ";";

	namedcontent ~= format(content, zone, absolutePath(var["zonefile"]), extra);
}

void writeNamedConf()
{
	string namedfil = parser.parse(Element(Element.Type.LINE, var["namedconf"])).data;
	var["namedconf"] = namedfil; //zpatky ulozime zparsovane
	
	if (namedfil.exists && namedfil.isFile)
		rename(namedfil, namedfil ~ ".bak");
	if (namedfil.exists && !namedfil.isFile)
		throw new Exception("file " ~ namedfil ~ " exists, but is not a file");
	auto file = File(namedfil, "w");
	file.write(namedcontent);
	file.close;
}
