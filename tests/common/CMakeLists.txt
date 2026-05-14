rv_add_rtl(
    TESTBENCHES
        ${CMAKE_CURRENT_SOURCE_DIR}/util.sv
)

set(RV_TESTS_COMMON_DIR ${CMAKE_CURRENT_SOURCE_DIR})

add_library(libsyscall STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/syscall.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/syscall.s
)

target_compile_options(libsyscall PRIVATE
    ${COMMON_COMPILE_OPTIONS}
    -fno-exceptions
    -fno-rtti
)

add_subdirectory(elf)
add_subdirectory(csv)

add_library(libutil STATIC
    ${CMAKE_CURRENT_SOURCE_DIR}/util.cpp
)

find_package(GTest CONFIG REQUIRED)
target_link_libraries(libutil 
    PRIVATE 
        GTest::gtest 
        GTest::gtest_main 
        GTest::gmock 
        GTest::gmock_main
        elf)

target_include_directories(libutil PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/
)


