import std.stdio, std.file, std.functional, std.c.stdlib;
import vars, cmds, eparser, gen;
static import globals;

void setDefaults()
{
	var["template_suffix"] = ".tpl";
	var["template_dir"] = ".";
	var["zone_suffix"] = ".db";
	var["zone_dir"] = ".";
	var["version_suffix"] = ".ver";
	var["version_dir"] = ".";
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

void printVer()
{
	import core.runtime:Runtime;
	import std.path:baseName;
	string myname = baseName(Runtime.args()[0]);
	string ver = myname ~ " " ~ globals.VERSION ~ "\n\nWritten by Martin Krejčiřík";
	writeln(ver);
}

void printHelp()
{
	import core.runtime:Runtime;
	import std.path:baseName;
	string myname = baseName(Runtime.args()[0]);
	string help = r"
Usage: " ~ myname ~ " [OPTION] [ZONE]...
Generate zone files from templates. Optional ZONE specifies which zones to (re)generate.
By default all changed zones are generated.
	
  --all          process all zones, including unchanged
  --config       configuration template. Default is config.tpl
  --force-serial increment serial number even for unchanged zones
  --help         display this text and exit
  --version      output version information and exit
";
	writeln(help);
}

void main(string[] args)
{
	string filename = "config.tpl";
	if (args.length>1) foreach(arg; args[1..$])
	{
		switch (arg)
		{
			case "--all": globals.opts["all"] = ""; stderr.writeln("Warning: option --all not implemented"); break;
			case "--config": filename = null; break;
			case "--force-serial": globals.opts["forceserial"] = ""; stderr.writeln("Warning: option --force-serial not implemented"); break;
			case "--help": printHelp; exit(EXIT_SUCCESS); break;
			case "--version": printVer; exit(EXIT_SUCCESS); break;
			default:
				if (filename is null)
					filename = arg;
				else if (arg[0] != '-')
					globals.forcedzones ~= arg;
				else { stderr.writefln("invalid option '%s'", arg); printHelp; exit(EXIT_FAILURE); }
		}
	}
	setDefaults();

	parser = new EParser;
	parser.onSet = &var.put;   /* run when variable is set (!var=somthing) */
	parser.onVar = &var.get;   /* run when variable is inserted (something !var) */
	parser.onCmd = &cmd.doCmd; /* run on command ( SOA(zone.cz) ) */

	cmd["DOMAIN"] = toDelegate(&genZone!"forward");
	cmd["REVERSE"] = toDelegate(&genZone!"reverse");
	cmd["PTR"] = toDelegate(&cmdPTR);
	Element e = { Element.Type.FILE };
	try {
	e.data = cast(string) read(filename, globals.MAXSIZE);
	auto r = parser.parse(e);
	} catch (FileException e) { stderr.writeln("Error accessing file ", e.msg); exit(EXIT_FAILURE); }

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
