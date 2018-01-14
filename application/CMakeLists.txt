cmake_minimum_required(VERSION 3.8)

project(cmake_whole_archive_app VERSION 1.0.0)

add_executable(main main.cc)

message("CMAKE_CXX_COMPILER_ID: ${CMAKE_CXX_COMPILER_ID}")

find_package(cmake_whole_archive_lib CONFIG REQUIRED)
target_link_libraries(main PUBLIC cmake_whole_archive_lib::dummy) # transitive -> ::http

### test ###

enable_testing()
add_test(link_test main)

### install ###

install(TARGETS main DESTINATION bin)
