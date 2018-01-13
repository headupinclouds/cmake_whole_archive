#ifndef _http_h_
#define _http_h_

#include <map>

typedef void (*handler)(const char *protocol);
typedef std::map<const char *, handler> M;
void register_handler(const char *protocol, handler h);

#endif // _http_h_
