import std.stdio, std.file, std.functional;
import vars, cmds, eparser, gen;

void main(string[] args)
{
	string filename;
	if (args.length > 1)
		filename = args[1];
	else
		filename = "config.tpl";

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
