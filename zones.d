module zones;

import std.conv, std.datetime, std.file;
import vars;
static import globals;

Zone currentZone;

/* must be scope to enforce that destructor is run */
scope final class Zone
{
  private:
	static bool[string] _instantiated; // does the zone already exist ?
	string		_name;		// domain
	string		_tplfil;	// tpl filename
	string		_verfil;	// version filename
	string		_zonfil;	// zone filename
	uint 		_sn;		// S/N
	uint		_sn_old;	// old S/N
	SysTime		_veracc;	// old version filename accessTime
	SysTime		_vermod;	// old version filename modificationTime
	bool		_revertVer;	// revert to old S/N on writing
	bool		_changed;	// has zone changed ?

  public:
	string ipnetwork;		// uses cmdPTR
	bool forced = false; 	// is zone forced (updated even if unchanged) ?

	this(string zonstr, string file = null)
	{
		if (zonstr !in _instantiated)
			_instantiated[zonstr] = true; // pro multithread pouzit rwmutex na AA plus shared bool. Shared AA ne(staci).
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

		readSerial();
	}

	~this()
	{
		writeSerial();
		var.zone = null; // important for vars.get|put and elsewhere
		currentZone = null;
		synchronized _instantiated.remove(_name);
	}

  public:
	auto name() @property { return _name; }
	auto tplfil() @property { return _tplfil; }
	auto verfil() @property { return _verfil; }
	auto zonfil() @property { return _zonfil; }
	auto changed() @property { return _changed; }

	/* check if zone template changed */
	bool tplChanged()
	{
		return _changed = timeLastModified(_tplfil) > timeLastModified(_verfil, SysTime.min);
	}

	/* read serial number from file */
	uint readSerial()
	{
		if (var["version_suffix"].length < 3)
			throw new Exception(__FUNCTION__ ~ "(): version file suffix " ~ var["version_suffix"] ~" not allowed)");
		string ver_old = "0"; //required when version file missing
		try {
			getTimes(_verfil, _veracc, _vermod);
			ver_old = cast(string) std.file.read(_verfil, 10);
		} catch (FileException e) {}

		_sn_old = to!uint(ver_old);	//old version from file
		_sn = _sn_old;
		assert(var.zone == _name);
		var["version"] = ver_old;
		return _sn;
	}

	/* write serial number to file */
	void writeSerial()
	{
		import std.stdio;
		if (! _changed)
			return;
		assert(var.zone == _name);
		assert(_vermod.toUnixTime);
		string ver = to!string(_sn);
		try {
			std.file.write(_verfil, ver);
			if (_revertVer)
				setTimes(_verfil, _veracc, _vermod);
		} catch (FileException e) { globals.errcount++; stderr.writeln("Error writing ", e.msg); }
	}

	/* increment serial number */
	string incSerial()
	{
		_changed = true;
		_sn = to!uint(Clock.currTime.toISOString[0..8] ~ "00"); //new version from clock
		if (_sn <= _sn_old)
			_sn = _sn_old + 1;

		string ver = to!string(_sn);
		assert(var.zone == _name);
		var["version"] = ver;
		return ver;
	}

	/* revert time of version file to force rebuild, keep new S/N to stay in sync with zone file */
	void revertVer()
	{
		_revertVer = true;
	}
}
