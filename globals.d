module globals;

enum VERSION = "v0.6.2";
enum MAXSIZE = 1024*1024*100;	// max file size to read

string[string] opts;			// commandline parsed options
string[] forcedzones;			// zones to process even if unchanged
int errcount;					// error counter (incremented during zone generation)
int changecount;				// change counter (incremented during zone generation)

static assert(__VERSION__ >= 2065, "Please upgrade your compiler");
