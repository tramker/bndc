module vars;
import std.array;
debug import std.stdio;

Vars var;

static this()
{
	var["origin"] = "@"; // pouziva NS
}

struct Vars
{
private:
	string[string] _global_vars; /* user-defined vars */
	string[string][string]  _zone_vars;
	string _zone;
public:

	string opCall(string id) { return get(id); }
	string opIndex(string id) { return get(id); }
	void opIndexAssign(string arg, string id) { put(id, arg); }
	
	void zone(string z) @property { _zone = z; }
	
    /* vracena hodnota jde zpet do parseru */
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

    /* vracena hodnota jde zpet do parseru */
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
