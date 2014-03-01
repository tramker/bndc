import std.stdio, std.file, std.functional;
import vars, cmds, eparser, gen;

void setDefaults()
{
	var["template_suffix"] = ".tpl";
	var["template_dir"] = ".";
	var["zone_suffix"] = ".db";
	var["zone_dir"] = ".";
	var["version_suffix"] = ".ver";
	var["header"] = "header.tpl";
	var["footer"] = "footer.tpl";
	var["ttl"] = "1d";
	var["refresh"] = "4h";
	var["retry"] = "1h";
	var["expire"] = "30d";
	var["negttl"] = "15m";
	var["nsname"] = "localhost.";
	var["maintname"] = "root.localhost.";
	var["rrttl"] = "";
	var["namedconf"] = "!zone_dir/named-zones.conf";
	var["cmd_reload"] = "rndc reload";
	var["cmd_checkzone"] = "/usr/sbin/named-checkzone -i local !zone !zonefile";
	var["cmd_checkconf"] = "/usr/sbin/named-checkconf !namedconf";
}

void main(string[] args)
{
	string filename;
	if (args.length > 1)
		filename = args[1];
	else
		filename = "config.tpl";
		
	setDefaults();

	parser = new EParser;
	parser.onSet = &var.put;   /* run whe variable is set (!var=somthing) */
	parser.onVar = &var.get;   /* run wher variable is inserted (something !var) */
	parser.onCmd = &cmd.doCmd; /* run on command ( SOA(zone.cz) ) */

	cmd["DOMAIN"] = toDelegate(&genDomain);
	cmd["REVERSE"] = toDelegate(&genReverse);
	cmd["PTR"] = toDelegate(&cmdPTR);
	Element e = { Element.Type.FILE };
	e.data = cast(string) read(filename, MAXSIZE);
	auto r = parser.parse(e);
	
	if (errcount)
		stderr.writefln("%d errors encountered, not reloading", errcount);
	else if (changecount)
	{
		writeNamedConf;
		if (!runCheckConf)
			runReload;
	}

	//stdout.write(namedconf);
}
