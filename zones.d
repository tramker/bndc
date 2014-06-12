module zones;

import std.stdio, std.conv, std.datetime, std.file;
import vars;
//static import globals;

Zone currentZone;

scope class Zone
{
  private:
	static shared bool[string]	_instantiated; // existuje jiz tato zona ?
	string		_name;		// domena
	string		_tplfil;	// tpl filename
	string		_verfil;	// version filename
	string		_zonfil;	// zone filename
	uint 		_sn;		// S/N
	string 		_sn_new;	// new S/N string
	string		_sn_old;	// old S/N string

  public:
	string ipnetwork; // pouziva cmdPTR

	this(string zonstr, string file = null)
	{
		if (zonstr !in _instantiated)
			synchronized _instantiated[zonstr] = true;
		else
			assert(0, "Zone " ~ zonstr ~ " already instantiated");

		if (zonstr.length < 1)
			throw new Exception(__FUNCTION__ ~ "(): missing zone name");

		_name = zonstr;
		assert(var.zone != zonstr);
		var.zone = zonstr;
		assert(currentZone is null);
		currentZone = this;

		if (file !is null)
			zonstr = file; //use this filename instead
		_tplfil = var["template_dir"] ~ "/" ~ zonstr ~ var["template_suffix"];
		_verfil = var["version_dir"]  ~ "/" ~ zonstr ~ var["version_suffix"];
		_zonfil = var["zone_dir"]     ~ "/" ~ zonstr ~ var["zone_suffix"];
		var["zonefile"] = _zonfil;
	}

	~this()
	{
		var.zone = null; // dulezite pro vars.get|put a jinde
		currentZone = null;
		synchronized _instantiated.remove(_name);
	}

  public:
	auto name() @property { return _name; }
	auto tplfil() @property { return _tplfil; }
	auto verfil() @property { return _verfil; }
	auto zonfil() @property { return _zonfil; }

	/* check if zone template changed */
	bool changed()
	{
		return timeLastModified(_tplfil) > timeLastModified(_verfil, SysTime.min);
	}

	/* generate and remember zone serial number */
	string genSerial()
	{
		if (var["version_suffix"].length < 3)
			throw new Exception(__FUNCTION__ ~ "(): version file suffix " ~ var["version_suffix"] ~" not allowed)");
		string verfil = var["version_dir"] ~ "/" ~ _name ~ var["version_suffix"];
		string verstr = "0"; //required when version file missing
		uint newver = to!uint(Clock.currTime.toISOString[0..8] ~ "00"); //new version from clock
		try { verstr = cast(string) std.file.read(verfil, 10); } catch (FileException e) {}
		uint oldver = to!uint(verstr); //old version from file

		if (newver <= oldver)
			newver = oldver + 1;

		_sn_old = verstr;
		verstr = to!string(newver);
		_sn_new = verstr;
		try { std.file.write(verfil, verstr); } catch (FileException e) { stderr.writeln("Error writing ", e.msg); }
		return verstr;
	}

	void revertSerial()
	{
		writeln("revertSerial() not implemented");
	}
}
