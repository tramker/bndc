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
	var["cmd_reload"] = "rndc reload";
	var["cmd_check"] = "/usr/sbin/named-checkzone !zone !file";
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

	//stderr.writeln(r);
}
