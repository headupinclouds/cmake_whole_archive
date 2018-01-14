#include "http.h"
struct HttpHandler
{
    HttpHandler() { register_handler("http", &handle_http); }
    static void handle_http(const char *) { /* whatever */ }
};
HttpHandler h; // registers itself with main!
