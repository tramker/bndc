module ipaddr;
import std.stdio, std.string, std.conv, std.algorithm;

/* pocita pocet nulovych bitu zprava, vrati ale jako zleva */
@safe pure nothrow
int bitcount (uint v)
{
	import core.bitop:bsf;
	return v ? 32-bsf(v) : 32; //BSF result undefined for 0 input
}

struct IPv4
{
	uint addr;
	uint mask;

	this (string ipstr) { this = fromString(ipstr); }

	static IPv4 fromString(string ipstr)
	{
		IPv4 ret;
		string adstr = ipstr;
		string nmstr = null;
		auto f = findSplit(ipstr, "/");
		if (f[1].length)
		{
			adstr = f[0];
			nmstr = f[2];
			ret.mask = uint.max<<(32-to!uint(nmstr));
		}
		auto arr = adstr.split('.');
		if (arr.length>4)
			throw new Exception("bad IP address: " ~ adstr);
		if (nmstr is null)
			ret.mask = uint.max<<(32-arr.length*8);
		assert(ret.addr == 0);
		for(ubyte i,sh=24; i<arr.length; i++,sh-=8)
			ret.addr |= to!ubyte(arr[i])<<sh;
		return ret;
	}
	
	static string toString(IPv4 s, bool mask=false)
	{
		if (mask)
			return format("%d.%d.%d.%d/%d", s.addr>>24, s.addr<<8>>24, s.addr<<16>>24, s.addr<<24>>24, bitcount(s.mask));
		else
			return format("%d.%d.%d.%d", s.addr>>24, s.addr<<8>>24, s.addr<<16>>24, s.addr<<24>>24);
	}

	string toString(bool mask=false) { return toString(this, mask); }
	
	bool isin(IPv4 rhs) { return ((addr&rhs.mask) == (rhs.addr&rhs.mask)); }
	
	/* obraceny string (domena) pro pouziti v reverznich zonach */
	string toReverseZone()
	{
		char[] ret; ret.length = 30;
		uint pos = "in-addr.arpa".length;
		ret[$-pos..$] = "in-addr.arpa";
		for(uint a=addr,sh=0; a>0&&sh<=32; sh+=8)
		{
			a = addr<<sh>>24;
			if (a)
			{
				string num = to!string(a) ~ ".";
				uint end = ret.length - pos;
				pos += num.length;
				//debug stderr.writefln("BOUNDS: %d .. %d, %d", ret.length-pos, end, num.length);
				ret[$-pos..end] = num;
			}
		}
		ret = ret[$-pos..$];
		//debug stderr.writefln("RET: %s", ret);
		return cast(immutable) ret;
		//return format("%d.%d.%d.in-addr.arpa", addr<<16>>24, addr<<8>>24, addr>>24);
	}

	/* obraceny string (jen host IP) pro pouziti v reverznich zonach */
	string toReverseHost(string net)
	{
		import std.array: join;
		auto had = addr ^ fromString(net).addr; // addr xor net = host addr
		string[] ret; ret.reserve(3);
		for(uint a=had,sh=0; sh<=32; sh+=8)
		{
			a = had<<sh>>24;
			if (a)
				ret ~= to!string(a);
		}
		//debug stderr.writeln("RET: ", join(ret.reverse, "."));
		return join(ret.reverse, ".");
	}
}

struct IPv6
{
	ubyte[16] addr;
	ubyte[16] mask;
	
	this (string ipstr) { }
}

unittest
{
	auto ip1 = IPv4("192.168.0.1");
	auto ip2 = IPv4("192.168.0.0/24");
	assert(ip1.toString(true) == "192.168.0.1/32");
	assert(ip2.toString(true) == "192.168.0.0/24");
	assert(ip1.isin(ip2));
	static assert(IPv4.fromString("172.16.10.1").mask.bitcount == 32);
	static assert(IPv4.fromString("172.16.10.1").addr == 0xAC100A01);
	static assert(IPv4.fromString("172.16.10.1/30").mask.bitcount == 30);
	static assert(IPv4.fromString("172.16.10").mask.bitcount == 24);
	static assert(IPv4.fromString("172.16").mask.bitcount == 16);
	static assert(IPv4.fromString("10").mask.bitcount == 8);
}
