module cmds;
import std.stdio, std.string, std.algorithm, std.range, std.array;
import vars, hosts;

Cmds cmd;

static this()
{
	cmd._cmd = [
	"TTL"   : (string[] args) => format("$TTL %s", args[0]),
	"SOA"   : (string[] args) => "!origin\t!rrttl\tSOA !nsname !maintname (!version !refresh !retry !expire !negttl)", //fixme - kontrolovat !zone==args[0]
	"NS"    : (string[] args) => args.map!(a => "!origin\t!rrttl\tNS\t"~a).join("\n"),
	"MX"    : (string[] args) => args.map!(a => "!origin\t!rrttl\tMX\t"~a).join("\n"),
	"A"     : (string[] args) { var["host"]=args[0]; return args[0]~"\t!rrttl\tA\t"~args[1]; },
	"AAAA"  : (string[] args) { var["host"]=args[0]; return args[0]~"\t!rrttl\tAAAA\t"~args[1]; },
	"H"     : (string[] args) { var["host"]=args[0]; return ""; },
	"CNAME" : (string[] args) => args.map!(a => a~"\t!rrttl\tCNAME\t!host").join("\n"),
	"PTR"   : null,
	"DOMAIN" : null,
	"REVERSE": null
	];
}

struct Cmds
{
	private: /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	string delegate(string[] args)[string] _cmd; /* key is command name */

	public:  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	/* returned value goes back to the parser */
	string doCmd(string id, string[] args)
	{
		debug stderr.writefln("DEBUG doCmd(%d): %s %s", args.length, id, args);
		if (id in _cmd && _cmd[id] !is null)
			return  _cmd[id](args);
		else
		{
			import zones; static import globals;
			globals.errcount++;
			if (currentZone !is null) // we are not in the config template
				stderr.writefln("Error in template %s: unknown command %s", currentZone.tplfil, id);
			return "; bndc error: unknown command " ~ id;
		}
	}
	
	auto opIndex(string id)
	{
		if (auto valp = id in _cmd)
			return *valp;
		else throw new Exception("Command " ~ id ~ " not defined");
	}

	void opIndexAssign(string delegate(string[]) dg, string id)
	{
		if (auto valp = id in _cmd)
			*valp = dg;
		else throw new Exception("Command " ~ id ~ " not defined");
	}
}

unittest
{
	import std.exception;
	auto c = cmd["MX"];
	cmd["MX"] = c;
	assert(cmd._cmd["TTL"] == cmd["TTL"]);
	assertThrown!Exception(cmd["NONEEXISTENT"]);
}
