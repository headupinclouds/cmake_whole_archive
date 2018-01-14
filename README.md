# cmake_whole_archive

This project contains a minimal yet functional simple test to illustrate proper use of "wholearchive" compiler flags when linking executables with certain static libraries.  Both in project (build tree) and post installed pkconfig cases (i.e., `find_package(BAR CONFIG REQUIRED)` + `target_link_libraries(FOO PUBLIC BAR::bar)`) are demonstrated.  The following test case is reproduced from this stackoverflow.com post (with a few build fixes):

https://stackoverflow.com/a/842770

The above post outlines a common use cases where global instances are registered in a common table using constructor side effects.  The source from the original SO post is reproduced here (inline) with some minor build related fixes:

library/main.cc:
```
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
```

library/http.cc: (part of libhttp.a)
```
#include "http.h"
struct HttpHandler
{
    HttpHandler() { register_handler("http", &handle_http); }
    static void handle_http(const char *) { /* whatever */ }
};
HttpHandler h; // registers itself with main!

```

library/CMakeLists.txt (in project build)
```
cmake_minimum_required(VERSION 3.8)
project(cmake_whole_archive_lib VERSION 1.0.0)
add_library(http STATIC http.cc)
add_executable(main main.cc)

# https://github.com/caffe2/caffe2/blob/f2cf8933fc8c04f149ea27f30381517df358c1b5/cmake/Utils.cmake#L173-L185
function(add_whole_archive_flag lib output_var)
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(${output_var} -Wl,-force_load,$<TARGET_FILE:${lib}> PARENT_SCOPE)
  elseif(MSVC)
    # In MSVC, we will add whole archive in default.
    set(${output_var} -WHOLEARCHIVE:$<TARGET_FILE:${lib}> PARENT_SCOPE)
  else()
    # Assume everything else is like gcc
    set(${output_var} -Wl,--whole-archive ${lib} -Wl,--no-whole-archive PARENT_SCOPE)
  endif()
endfunction()

option(USE_WHOLE_ARCHIVE "Use wholearchive linking" OFF)

# This alias can "fix" the pkgconfig installation
option(USE_ALIAS "Use library alias for pkgconfig installation" OFF)
if(USE_ALIAS)
  set(http_alias "${namespace}http")
  add_library(${http_alias} ALIAS http)
else()
  set(http_alias http)
endif()

if(USE_WHOLE_ARCHIVE)
  # for error "ld: file not found: /cmake_whole_archive/_builds/xcode/Release/libhttp.a"
  add_dependencies(main http) # without this it will fail
  add_whole_archive_flag(${http_alias} http_link_command)
else()
  set(http_link_command http)
endif()

add_library(dummy dummy.cpp)
target_link_libraries(dummy PUBLIC ${http_link_command})
  
target_link_libraries(main PUBLIC ${http_link_command})
```

This CMakeLists.txt file illustrates use of "wholearchive" flags in the executable `target_link_library()` call, which forces linking of all symbols regardless of whether or not they are used/referenced.  The "wholearchive" flags are shown for common compilers here:

  * CLANG : `-force_load FOO`
  * MSVC  : `-WHOLEARCHIVE FOO`
  * GCC   : `--whole_archive FOO --no-whole-archive`
  

If we are consuming the post installation pkgconfig libraries from the library installation (see [CMakeLists.txt](https://github.com/headupinclouds/cmake_whole_archive/blob/00d7caed7e4e5c96d6d29c82a935d73bef651687/library/CMakeLists.txt#L89-L163) installation) in a users's executable (see [CMakeLists.txt](https://github.com/headupinclouds/cmake_whole_archive/blob/00d7caed7e4e5c96d6d29c82a935d73bef651687/application/CMakeLists.txt#L9-L10)), then the `main.cpp` application would be identical to the build tree version, but the CMake code will link the installed library use `find_package() + target_link_libraries()`.

application/CMakeLists.txt

```
cmake_minimum_required(VERSION 3.8)
project(cmake_whole_archive_app VERSION 1.0.0)
add_executable(main main.cc)

find_package(cmake_whole_archive_lib CONFIG REQUIRED)
target_link_libraries(main PUBLIC cmake_whole_archive_lib::dummy) # transitive -> ::http

### test ###

enable_testing()
add_test(link_test main)

### install ###

install(TARGETS main DESTINATION bin)
```

In this case we are linking the top level `dummy` library target to our `main` application, which introduces the `http` transitive dependency.  When the `USE_WHOLE_ARCHIVE=ON` option is enabled in the library build the various "wholearchive" flags are injected directly in the pkcconfig files via the `target_link_libraries()` calls.  In particular, for the `cmake_whole_archive_libTargets.cmake` that is genreated by the library's CMake `configure_package_config_file` 

i.e.,
```
configure_package_config_file(
    "cmake/Config.cmake.in"
    "${project_config}"
    INSTALL_DESTINATION "${config_install_dir}"
)
```

When `USE_ALIAS=OFF` we see:


`${CMAKE_INSTALL_PREFIX}/lib/cmake/cmake_whole_archive_lib/cmake_whole_archive_libTargets.cmake`:
```
### snip ###
set_target_properties(cmake_whole_archive_lib::dummy PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${_IMPORT_PREFIX}/include"
  INTERFACE_LINK_LIBRARIES "-Wl,-force_load,\$<TARGET_FILE:http>"
)
### snip ###
```

and the target executable dies with an error.

When `USE_ALIAS=ON` then the namespace target syntax is propagated to the pkconfig files and we see:

`${CMAKE_INSTALL_PREFIX}/lib/cmake/cmake_whole_archive_lib/cmake_whole_archive_libTargets.cmake`:
```
### snip ###
set_target_properties(cmake_whole_archive_lib::dummy PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${_IMPORT_PREFIX}/include"
  INTERFACE_LINK_LIBRARIES "-Wl,-force_load,\$<TARGET_FILE:cmake_whole_archive_lib::http>"
)
### snip ###
```

Which make the final `main` target happy.

References:
* https://gitlab.kitware.com/cmake/cmake/issues/16947
* cmake add_whole_archive_flag function from [caffe](https://github.com/caffe2/caffe2/blob/7770f511d619975205d37dac4d2a6a83708515e2/cmake/Utils.cmake#L175-L185)
* [cmake discussion](https://cmake.org/pipermail/cmake/2016-May/063359.html) about `--whole-archive` flags and why they aren't used in `INTERFACE_LINK_OPTIONS` -- OBJECT libraries are suggested, although OBJECT libraries have a number of other issues (and xcode limitations) oulined in [CGold](http://cgold.readthedocs.io/en/latest/rejected/object-libraries.html?highlight=object)'s object library overview
