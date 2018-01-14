#include "http.h"
#include <iostream>

M m;

void register_handler(const char *protocol, handler h)
{
    m[protocol] = h;
}

int main(int argc, char *argv[])
{
    return (m.find("http") == m.end()); // 0 on success
}
