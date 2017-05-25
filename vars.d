module vars;
import std.array;
debug import std.stdio;

Vars var;

static this()
{
	/* system sets: !host, !zone, !zonefile, !version */
	var["template_suffix"] = ".tpl";
	var["template_dir"] = ".";
	var["zone_suffix"] = ".db";
	var["zone_dir"] = ".";
	var["version_suffix"] = ".ver";
	var["version_dir"] = ".";
	//var["header"] = "header.tpl";
	//var["footer"] = "footer.tpl";
	var["ttl"] = "1d";
	var["refresh"] = "4h";
	var["retry"] = "1h";
	var["expire"] = "30d";
	var["negttl"] = "15m";
	var["nsname"] = "localhost.";
	var["maintname"] = "root.localhost.";
	var["rrttl"] = "";   // used by commands !SOA,!NS,!MX,!A,!AAAA,!CNAME
	var["origin"] = "@"; // used by commands !SOA,!NS,!MX
	var["namedconf"] = "!zone_dir/bndc-zones.conf";
	var["cmd_reload"] = "rndc reload";
	var["cmd_checkzone"] = "/usr/sbin/named-checkzone -i local !zone !zonefile";
	var["cmd_checkconf"] = "/usr/sbin/named-checkconf !namedconf";
}

struct Vars
{
	private: /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	string[string]			_global_vars;  /* global user-defined vars */
	string[string][string]	_zone_vars;    /* per zone user-defined vars */
	string					_zone;

	public:  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	string opCall(string id) { return get(id); }
	string opIndex(string id) { return get(id); }
	void opIndexAssign(string arg, string id) { put(id, arg); }
	
	void zone(string z) @property { _zone = z; }
	string zone() @property { return _zone; }
	
    /* returned value goes back to parser */
	string get(string id) @property
	{
		//debug stderr.writefln("DEBUG get(): [%s] %s", _zone, id);
		if (id == "zone")
			return _zone;
		if (_zone !is null && _zone in _zone_vars && id in _zone_vars[_zone])
			return _zone_vars[_zone][id];
		else
			return id in _global_vars ? _global_vars[id] : "";
	}

    /* returned value goes back to parser */
	string put(string id, string arg) @property
	{
		//debug stderr.writefln("DEBUG put(): [%s] %s %s", _zone, id, arg);
		if (id == "zone")
			throw new Exception("setting !zone variable not allowed");
		else if (_zone !is null)
			_zone_vars[_zone][id] = arg;
		else
			_global_vars[id] = arg;
		return null;
	}
	
	void remove(string id) @property
	{
		//debug stderr.writefln("DEBUG remove(): [%s] %s %s", _zone, id);
		if (id == "zone")
			throw new Exception("removing !zone variable not allowed");
		else if (_zone !is null)
			_zone_vars[_zone].remove(id);
		else
			_global_vars.remove(id);
	}
}
