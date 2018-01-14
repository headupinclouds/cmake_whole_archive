# https://gitlab.kitware.com/cmake/cmake/issues/16947
#
# A simple test to illustrate valid/required use of
#  * CLANG : -force_load
#  * MSVC  : -WHOLEARCHIVE
#  * GCC   : --whole_archive --no-whole-archive
#
# Stackoverflow sample code:
#
#  https://stackoverflow.com/a/842770
#
# CMake caffe_add_whole_archive_flag function:
#
#  https://github.com/caffe2/caffe2/blob/7770f511d619975205d37dac4d2a6a83708515e2/cmake/Utils.cmake#L175-L185
#
# 
# Background:
#
# There has been some discussion of INTERFACE_LINK_OPTIONS on the developer mailing
# list but nothing has been implemented.  Even if it were, it wouldn't be appropriate
# for --whole-archive anyway.  Not all toolchains support --whole-archive, so CMake
# has no porcelain for it.  Instead we offer object libraries for the use case.

# https://cmake.org/pipermail/cmake/2016-May/063359.html
#
# Currently adding --whole-archive to INTERFACE_LINK_LIBRARIES is not well
# defined.  It is only safe to add such flags in the target_link_libraries
# call of the final binary.  This would be done on the client side.  Therefore
# all of the above steps to simulate it should be done on the client side too
# and there is no need to do anything ahead of time or install anything.
#
# The way we express this on the client side with OBJECT libraries is
# to specify $<TARGET_OBJECTS:objlib> as sources of the consuming target
# in its add_library or add_executable call.  This eliminates any sense
# of "linking" to the library in CMake's model of the project and therefore
# avoids having to define semantics for usage requirements and transitive
# linking of object libraries.

# https://msdn.microsoft.com/en-us/library/mt732963.aspx

cmake_minimum_required(VERSION 3.8)

project(cmake_whole_archive_lib VERSION 1.0.0)

set(namespace "${PROJECT_NAME}::")

add_library(http STATIC http.cc)

add_executable(main main.cc)

message("CMAKE_CXX_COMPILER_ID: ${CMAKE_CXX_COMPILER_ID}")

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

set(http_alias "${namespace}http")
add_library(${http_alias} ALIAS http)

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

### test ###

enable_testing()
add_test(link_test main)

### install ###

install(TARGETS main DESTINATION bin)

# Installation (https://github.com/forexample/package-example) {

# Layout. This works for all platforms:
#   * <prefix>/lib/cmake/<PROJECT-NAME>
#   * <prefix>/lib/
#   * <prefix>/include/
set(config_install_dir "lib/cmake/${PROJECT_NAME}")
set(include_install_dir "include")

set(generated_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")

# Configuration
set(version_config "${generated_dir}/${PROJECT_NAME}ConfigVersion.cmake")
set(project_config "${generated_dir}/${PROJECT_NAME}Config.cmake")
set(TARGETS_EXPORT_NAME "${PROJECT_NAME}Targets")

# Include module with fuction 'write_basic_package_version_file'
include(CMakePackageConfigHelpers)

# Configure '<PROJECT-NAME>ConfigVersion.cmake'
# Use:
#   * PROJECT_VERSION
write_basic_package_version_file(
    "${version_config}" COMPATIBILITY SameMajorVersion
)

# Configure '<PROJECT-NAME>Config.cmake'
# Use variables:
#   * TARGETS_EXPORT_NAME
#   * PROJECT_NAME
configure_package_config_file(
    "cmake/Config.cmake.in"
    "${project_config}"
    INSTALL_DESTINATION "${config_install_dir}"
)

# Targets:
#   * <prefix>/lib/libhttp.a
#   * header location after install: <prefix>/include/http/http.h
#   * headers can be included by C++ code `#include <http/http.h>`
install(
    TARGETS dummy http
    EXPORT "${TARGETS_EXPORT_NAME}"
    LIBRARY DESTINATION "lib"
    ARCHIVE DESTINATION "lib"
    RUNTIME DESTINATION "bin"
    INCLUDES DESTINATION "${include_install_dir}"
)

# Headers:
install(
    FILES http.h
    DESTINATION "${include_install_dir}/http/"
)

# Config
#   * <prefix>/lib/cmake/http/httpConfig.cmake
#   * <prefix>/lib/cmake/http/httpConfigVersion.cmake
install(
    FILES "${project_config}" "${version_config}"
    DESTINATION "${config_install_dir}"
)

# Config
#   * <prefix>/lib/cmake/http/httpTargets.cmake
install(
    EXPORT "${TARGETS_EXPORT_NAME}"
    NAMESPACE "${namespace}"
    DESTINATION "${config_install_dir}"
)
# }