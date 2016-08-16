module hosts;
import std.stdio, std.string, std.container;
import std.algorithm:filter;
import vars;
public import ipaddr;

//private:
final class Host
{
	string  hn; //FQDN
	bool	changed;
	Addr4[] i4s;
	Addr6[] i6s;
	
	this(string h, bool ch=true) { hn = h; changed = ch; }
	override string toString() { return format("%s (%s IPv4, %s IPv6)", hn, i4s.length, i6s.length); }
}
final class Addr4
{
	IPv4	ad;
	bool	changed;
	Host[]	hns;
	
	this(IPv4 ip, bool ch=true) { ad = ip; changed = ch; }
	override string toString() { return format("%s (%s hosts)", ad, hns.length); }

}
final class Addr6
{
	IPv6	ad;
	bool	changed;
	Host[]	hns;

	this(IPv6 ip, bool ch=true) { ad = ip; changed = ch; }
	override string toString() { return format("%s (%s hosts)", ad, hns.length); }
}

//public:
Hostdb hostdb;

struct Hostdb
{
	private: /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	DList!Host		_host;
	DList!Addr4		_ipv4;
	DList!Addr6		_ipv6;
	Host[string]	ind_host;
	Addr4[IPv4]		ind_ipv4;
	Addr6[IPv6]		ind_ipv6;

	public:  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	void add4(string hostname, string addr, bool changed = true)
	{
		string domain;
		var["host"] = hostname;
		if (hostname == "@")
			hostname = var["zone"] ~ ".";
		else if (hostname[$-1] != '.')
			domain = "." ~ var["zone"] ~ ".";

		auto hn = hostname ~ domain;
		auto ip = IPv4(addr);
		if (hn !in ind_host)
		{
			_host.insertBack(new Host(hn, changed));
			ind_host[hn] = _host.back;
		}
		if (ip !in ind_ipv4)
		{
			_ipv4.insertBack(new Addr4(ip, changed));
			ind_ipv4[ip] = _ipv4.back;
		}

		ind_host[hn].i4s ~= ind_ipv4[ip];
		ind_ipv4[ip].hns ~= ind_host[hn];
		if (changed) ind_host[hn].changed = true; //nutne jen pro zmeny prirazenych ip adres
		if (changed) ind_ipv4[ip].changed = true; //nutne jen pro zmeny prirazenych hostnames

/*		debug {
			import std.stdio;
			stderr.writefln("DEBUG add4: %s %s", ind_host[hn].hn, ind_ipv4[ip].ad );
		}
*/
	}

	void add6(string hostname, string addr, bool changed = true)
	{
		var["host"] = hostname;
	}

	string toString()
	{
		import std.string;
		string ret;
		foreach (h; _host)
		{
			ret ~= h.hn ~ " (";
			foreach (ip; h.i4s)
				ret ~= format(" %s", ip);
			ret ~= format(" ) %s\n", h.changed ? "changed" : null);
		}
		ret ~= "\n";
		foreach (i; _ipv4)
		{
			ret ~= i.ad.toString ~ " (";
			foreach (h; i.hns)
				ret ~= format(" %s", h);
			ret ~= format(" ) %s\n", i.changed ? "changed" : null);
		}
		return ret;
	}

/* nepouziva se, misto toho filter s pred=true */
//	DList!Host  getHost()  { return _host; }
//	DList!Addr4 getAddr4() { return _ipv4; }
//	DList!Addr6 getAddr6() { return _ipv6; }

	const(Host)  opIndex(string hn) { return ind_host[hn]; }
	const(Addr4) opIndex(IPv4 ip)   { return ind_ipv4[ip]; }
	const(Addr6) opIndex(IPv6 ip)   { return ind_ipv6[ip]; }
}

enum FilterOpt { NONE, CHANGED }

/* Filter funkce s predikatem (alias pred) nemuzou byt member (chyba no frame access),
takze udelano vsechno jako UFCS. Idealne by melo vracet const, ale zatim neumime */
auto filterHost(alias pred)(Hostdb db)
{
	return filter!pred(db._host[]);
}

auto filterHost(FilterOpt OPT = FilterOpt.NONE)(Hostdb db, string arg)
{
	static if (OPT == FilterOpt.CHANGED)
		return filter!(a => a.changed && a.hn[arg.length<$ ? $-arg.length : 0 .. $] == arg)(db._host[]);
	else
		return filter!(a =>              a.hn[arg.length<$ ? $-arg.length : 0 .. $] == arg)(db._host[]);
}

auto filterIPv4(alias pred)(Hostdb db)
{
	return filter!pred(db._ipv4[]);
}

auto filterIPv4(FilterOpt OPT = FilterOpt.NONE)(Hostdb db, string arg)
{
	static if (OPT == FilterOpt.CHANGED)
		return filter!(a => a.changed && a.ad.isin(IPv4(arg)))(db._ipv4[]);
	else
		return filter!(a =>              a.ad.isin(IPv4(arg)))(db._ipv4[]);
}

auto filterIPv6(alias pred)(Hostdb db)
{
	return filter!pred(db._ipv6[]);
}

/*auto filterIPv6(FilterOpt OPT = FilterOpt.NONE)(Hostdb db, string arg)
{
	static if (OPT == FilterOpt.CHANGED)
		return std.algorithm.filter!(a => a.changed && a.ad.isin(IPv6(arg)))(db._ipv6[]);
	else
		return std.algorithm.filter!(a =>              a.ad.isin(IPv6(arg)))(db._ipv6[]);
}*/
