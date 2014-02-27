module cmds;
import std.string, std.algorithm, std.range, std.array;
import vars, hosts;
debug import std.stdio;

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
	"CNAME" : (string[] args) => args.map!(a => a~"\t!rrttl\tCNAME\t!host\t").join("\n"),
	"PTR"   : null,
	"DOMAIN" : null,
	"REVERSE": null
	];
}

struct Cmds
{
  private:
	string delegate(string[] args)[string] _cmd; /* key je jmeno prikazu */

  public:
    /* vracena hodnota jde zpet do parseru */
	string doCmd(string id, string[] args)
	{
		debug stderr.writefln("DEBUG doCmd(%d): %s %s", args.length, id, args);
		if (id in _cmd && _cmd[id] !is null)
			return  _cmd[id](args);
		else return "__" ~ id ~ "__";
	}
	
	auto opIndex(string id)
	{
		if (id !in _cmd)
			return _cmd[id];
		else throw new Exception("Command " ~ id ~ " not defined");
	}

	void opIndexAssign(string delegate(string[]) dg, string id)
	{
		if (id in _cmd)
			_cmd[id] = dg;
		else throw new Exception("Command " ~ id ~ " not defined");
	}
}
