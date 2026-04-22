add_executable(test_ooo)

rv_add_rtl(
    TESTBENCHES
        ${CMAKE_CURRENT_SOURCE_DIR}/mock_mem.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/ooo_tb.sv
)

get_target_property(RV_PACKAGES rv_rtl INTERFACE_RV_PACKAGES)
get_target_property(RV_INTERFACES rv_rtl INTERFACE_RV_INTERFACES)
get_target_property(RV_SOURCES rv_rtl INTERFACE_RV_SOURCES)
get_target_property(RV_TESTBENCHES rv_rtl INTERFACE_RV_TESTBENCHES)

verilate(test_ooo
    PREFIX Vooo
    TOP_MODULE ooo_tb
    SOURCES
        ${RV_PACKAGES}
        ${RV_INTERFACES}
        ${RV_SOURCES}
        ${RV_TESTBENCHES}
    INCLUDE_DIRS
        ${RV_INCLUDE_DIR}
        ${RV_SRC_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}/
    VERILATOR_ARGS
        --sv
        --trace
        --timing
        --main
        -Wall
        -Wno-fatal
        --trace-params
        --trace-structs
        --timescale "1ns/1ps"
        +define+VCD_DIR="${CMAKE_SOURCE_DIR}/"
)

target_compile_definitions(test_ooo PUBLIC
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
)
