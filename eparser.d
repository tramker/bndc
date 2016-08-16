/* simple parser for bndc
   input:
   - Element
   output:
   - Element
*/
module eparser;

import  std.array, std.string, std.algorithm, std.conv, std.regex, std.process;
//debug import std.stdio;

// enum RE = ctRexex!(r"");
auto RE_CMT    = regex(r"#.*");
//                       ___1_________________  - 1) nesmi tam byt !CMD(.*)
//auto RE_VARSET = regex(r"(?<!![A-Z_]+\(.*\).*)!(\w+)\s*=\s*([\w!.-]+|`.+`|" ~ `".*")[ \t]*`,"i");
auto RE_VARSET = regex(r"(?<!!\w+.*)!(\w+)\s*=\s*([\w!.-]+|`.+`|" ~ `".*")[ \t]*`,"i");
auto RE_VARID  = regex(r"!(\w+)(?![(=])\b");
auto RE_CMD    = regex(r"!([A-Z_]+)\(([A-Za-z0-9_ .:;!,@{}/*-]*)\)"); //pomlcka musi byt na konci
auto RE_SHELL  = regex(r"`(.+)`", "i");
auto RE_DQT    = regex(`"(.*)"`);
auto RE_WSLN   = regex(r"^\s+$");

//split argument parameters
string[] splitArg(string arg)
{
	string[] ret;
	foreach(t; arg.split(','))
		ret ~= strip(t);
	return ret;
}

struct Element
{
	enum Type : byte { ERR=-1, NUL=0, FILE, LINE, VAR, CMD }
	Type type = Type.ERR;
	string data;
	bool err() pure const { return type == Type.ERR; }
	private void err(bool e) { if (e) type = Type.ERR; }
}

/* Element parser */
class EParser
{
	private: /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	final void replaceVars(ref string data)
	{
		foreach(m; matchAll(data, RE_VARID))
			data = data.replaceFirst(m.hit, onVar(m[1]));
	}
	public:  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
	/* vraci typ ERR pri chybe a nezpracovana data */
	final Element parse(const Element e)
	{
		Element ret;   //zbyla data po odstraneni zparsovanych hodnot
		Element nextE; //dalsi data pro rekurznivni parsovani
		bool lineChanged = false; // zmenil se radek ? (pro mazani prazdnych radku)

		if (e.data.length >= uint.max)
			throw new Exception("Element " ~ to!string(e.data[0..64]) ~ "... too large");

		ret.data.reserve(e.data.length);
		string data = e.data; //nezpracovana data
		do //while (data.length)
		{
//			debug stderr.writefln("DEBUG_vstup: %s, '%s'", e.type, e.data);
//			debug stderr.writefln("DEBUG__data: '%s'", data);
			if (e.type == Element.Type.NUL)
			{
				ret.type = Element.Type.NUL;
				assert(data.length == 0);
				continue;
			} else
			if (e.type == Element.Type.FILE)
			{
				ret.type = Element.Type.FILE;
				auto f = data.findSplitAfter("\n");
				if (f[0].length) //nalezen radek
				{
					nextE = Element(Element.Type.LINE, f[0]);
					auto r = parse(nextE);
					ret.data ~= r.data;
					data = data[f[0].length..$];
				} else //posledni radek
				{
					nextE = Element(Element.Type.LINE, data);
					auto r = parse(nextE);
					ret.data ~= r.data;
					data.length = 0;
				}
			} else
			if (e.type == Element.Type.LINE)
			{
				ret.type = Element.Type.LINE;
				if (auto m = matchFirst(data, RE_CMT))
				{
					//debug stderr.writeln("DEBUG RE_CMT: ", m.hit);
					lineChanged = true;
					data = data[0..m.pre.length] ~ m.post; //post je \n
					/* smazani prazdnych radku (nadbytecne, pouze optimalizace) */
					if (data == "\n" || data == "\r\n" || data == "\r")
						data = null;
				} else
				if (auto m = matchFirst(data, RE_VARSET))
				{
					//debug stderr.writeln("DEBUG RE_VARSET: ", m.hit);
					lineChanged = true;
					auto varName = m[1]; auto varArg = m[2];
					nextE = Element(Element.Type.VAR, varArg);
					//replaceVars(nextE.data); //vyhodnoti promene v hodnote (nechceme)
					auto r = parse(nextE);
					string rdata = onSet(varName, r.data);
					ret.data = ret.data ~ m.pre ~ rdata; /* m.post se zpracuje v dalsim kole */
					data = data[m.pre.length+m.hit.length..$];
				} else
				if (auto m = matchFirst(data, RE_CMD))
				{
					//debug stderr.writeln("DEBUG RE_CMD: ", m.hit);
					lineChanged = true;
					auto cmdName = m[1]; auto cmdArg = m[2];
					replaceVars(cmdArg); //vyhodnoti promene v argumentu
					/* nepouzito
					nextE = Element(Element.Type.CMD, cmdArg);
					auto r = parse(nextE); */
					string rdata = onCmd(cmdName, splitArg(cmdArg));
					ret.data = ret.data ~ m.pre ~ rdata;       /* m.post zrusen */
					data = data[m.pre.length+m.hit.length..$]; /* m.post.length zruseno */
				} else // zadny match, konec smycky
				{
					ret.data ~= data;
					data.length = 0;
					/* smazani radku, ktere obsahuji jen mezery (pokud ze zmenily) */
					if (lineChanged)
						ret.data = replaceFirst(ret.data, RE_WSLN, "");
					if (! ret.data.length) // zbytecne
						ret.data = null;
				}
				replaceVars(ret.data); //vlozeni promenych do vysledku - zpracovava opakovane cely radek
			/* konec radku */
			} else
			if (e.type == Element.Type.VAR)
			{
				ret.type = Element.Type.VAR;
				if (auto m = matchFirst(data, RE_SHELL))
				{
					auto sh = executeShell(m[1]);
					if (sh.status) //return value
						ret.err = true;
					else if (sh.output)
						ret.data = sh.output.splitLines[0];
				} else
				if (auto m = matchFirst(data, RE_DQT))
				{
					ret.data = m[1];
				} else { ret.data = data; }
				data.length = 0;
			} else
			if (e.type == Element.Type.CMD) /* nepouzito */
			{
				ret = Element(Element.Type.NUL, null);
				data.length = 0;
			}

			if (ret.err)
			{
				auto end = e.data.length < 64 ? e.data.length : 64;
				throw new Exception("Parse error: " ~ to!string(e.data[0..end]) );
			}
		
		} while (data.length);
		return ret;
	} // Parse.parse()

	/* Callbacks */
	string delegate(string name) onVar;                /* pri pouziti promenne */
	string delegate(string name, string arg) onSet;    /* pri nastaveni promene */
	string delegate(string name, string[] args) onCmd; /* pri pouziti prikazu */

} // class Parse

unittest
{
	//import std.stdio;
	struct Test
	{
		string[string] _var;
		string var(string name) { return _var[name]; }
		string set(string name, string arg) { _var[name]=arg; return "_SET_"; }
		string cmd(string name, string[] args) { return "_CMD_" ~ args.join; }
	}
	
	Test t;
	auto e = Element(Element.Type.FILE, "START.#comment\n!var=jedna #promenna\n!CMD(!var)#prikaz\nEND.");
	auto p = new EParser;
	p.onVar = &t.var; p.onSet = &t.set; p.onCmd = &t.cmd;
	//p.parse(e).writeln;
	assert(p.parse(e).data == "START.\n_SET_\n_CMD_jedna\nEND.");
}
