cmake_minimum_required(VERSION 3.28)

project(RISCV LANGUAGES CXX)
enable_testing()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CheckCXXCompilerFlag)

# TODO: The CMake is incredibly messy right now. Clean it up.

set(RV_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl)

add_library(rv_rtl INTERFACE)

function(rv_add_rtl)
  cmake_parse_arguments(ARG
    ""
    ""
    "PACKAGES;INTERFACES;SOURCES;TESTBENCHES"
    ${ARGN})

  if(ARG_PACKAGES)
    set_property(TARGET rv_rtl APPEND PROPERTY
          INTERFACE_RV_PACKAGES ${ARG_PACKAGES})
  endif()

  if(ARG_INTERFACES)
    set_property(TARGET rv_rtl APPEND PROPERTY
          INTERFACE_RV_INTERFACES ${ARG_INTERFACES})
  endif()

  if(ARG_SOURCES)
    set_property(TARGET rv_rtl APPEND PROPERTY
          INTERFACE_RV_SOURCES ${ARG_SOURCES})
  endif()

  if(ARG_TESTBENCHES)
    set_property(TARGET rv_rtl APPEND PROPERTY
          INTERFACE_RV_TESTBENCHES ${ARG_TESTBENCHES})
  endif()
endfunction()

set(RV_INCLUDE_DIR
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_subdirectory(rtl)

target_sources(librv PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/sim/rv.cpp)

target_include_directories(librv PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/sim/)

target_compile_definitions(librv PUBLIC
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
    SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

add_subdirectory(tests)

find_package(Verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

add_executable(rv ${CMAKE_CURRENT_SOURCE_DIR}/sim/main.cpp)

target_include_directories(rv PRIVATE
    ${VERILATOR_ROOT}/include
)

target_link_libraries(rv PRIVATE
    librv
    argparse
)

set(SLANG_F_CONTENT
"-f ${CMAKE_CURRENT_BINARY_DIR}/tests/testbenches.f
-f ${CMAKE_CURRENT_BINARY_DIR}/rtl/rv.f
")

string(REPLACE ";" "\n" SLANG_F_CONTENT "${SLANG_F_CONTENT}")

set(RV_COMMAND_FILE ${CMAKE_CURRENT_BINARY_DIR}/slang.f)
file(WRITE ${RV_COMMAND_FILE} "${SLANG_F_CONTENT}\n")
# file(APPEND ${RV_COMMAND_FILE} "+incdir+${CMAKE_CURRENT_SOURCE_DIR}\n")
