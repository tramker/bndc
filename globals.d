module globals;

enum VERSION = "v0.5.0";
enum MAXSIZE = 1024*1024*100;	// max file size to read

string[string] opts;			// commandline parsed options
string[] forcedzones;			// zones to process even if unchanged
