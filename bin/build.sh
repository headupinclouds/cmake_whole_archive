#!/bin/bash

TOOLCHAIN=libcxx
CONFIG=Release

USE_WHOLE_ARCHIVE=ON

lib_output="library/_builds/${TOOLCHAIN}-${CONFIG}"
lib_args=(
  "-Hlibrary/"
  "-B${lib_output}"
  "-DCMAKE_BUILD_TYPE=${CONFIG}"
  "-DCMAKE_TOOLCHAIN_FILE=${PWD}/cxx11.cmake"
  "-DCMAKE_VERBOSE_MAKEFILE=ON"
  "-DPOLLY_STATUS_DEBUG=ON"
  "-DHUNTER_STATUS_DEBUG=ON"
  "-DCMAKE_INSTALL_PREFIX=library/_install/${TOOLCHAIN}"
  "-DUSE_WHOLE_ARCHIVE=${USE_WHOLE_ARCHIVE}"
  )

app_output="application/_builds/${TOOLCHAIN}-${CONFIG}"
app_args=(
  "-Happlication/"
  "-B${app_output}"
  "-DCMAKE_BUILD_TYPE=${CONFIG}"
  "-DCMAKE_TOOLCHAIN_FILE=${PWD}/cxx11.cmake"  
  "-DCMAKE_VERBOSE_MAKEFILE=ON"
  "-DPOLLY_STATUS_DEBUG=ON"
  "-DHUNTER_STATUS_DEBUG=ON"
  "-DCMAKE_INSTALL_PREFIX=application/_install/${TOOLCHAIN}"
  "-Dcmake_whole_archive_lib_DIR=${PWD}/library/_install/${TOOLCHAIN}/lib/cmake/cmake_whole_archive_lib"
)

mkdir -p library/_builds application/_builds

function run_test 
{
    (cd ${1} && ctest --verbose)
}

cmake ${lib_args[@]} -G"Unix Makefiles" && cmake --build ${lib_output} --target install && run_test ${lib_output} && \
cmake ${app_args[@]} -G"Unix Makefiles" && cmake --build ${app_output} --target install && run_test ${app_output}
