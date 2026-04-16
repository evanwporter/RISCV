find_package(Verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

add_library(librv)

rv_add_rtl(
    PACKAGES
        ${CMAKE_CURRENT_SOURCE_DIR}/constants.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/types.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/regs_types.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/rob_types.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/decoder_types.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/iq_types.sv
    INTERFACES
        ${CMAKE_CURRENT_SOURCE_DIR}/bus.sv
    SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/RISCV.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Renamer.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/IssueQueue.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/ReorderBuffer.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Dispatcher.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Decoder.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/ExecutionUnit.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/RegisterFile.sv
)

get_target_property(RV_PACKAGES rv_rtl INTERFACE_RV_PACKAGES)
get_target_property(RV_INTERFACES rv_rtl INTERFACE_RV_INTERFACES)
get_target_property(RV_SOURCES rv_rtl INTERFACE_RV_SOURCES)

set(RV_F_CONTENT
"${RV_PACKAGES}
${RV_INTERFACES}
${RV_SOURCES}
")

string(REPLACE ";" "\n" RV_F_CONTENT "${RV_F_CONTENT}")

set(RV_COMMAND_FILE ${CMAKE_CURRENT_BINARY_DIR}/rv.f)
file(WRITE ${RV_COMMAND_FILE} "${RV_F_CONTENT}\n")
file(APPEND ${RV_COMMAND_FILE} "+incdir+${CMAKE_CURRENT_SOURCE_DIR}\n")
file(APPEND ${RV_COMMAND_FILE} "+incdir+${RV_INCLUDE_DIR}\n")

verilate(librv
    PREFIX VGameboy
    SOURCES 
        ${RV_PACKAGES}
        ${RV_INTERFACES}
        ${RV_SOURCES}
    TOP_MODULE RISCV
    VERILATOR_ARGS
        --sv
        --trace-vcd
        # -Wall
        -I${RV_INCLUDE_DIR}
        -O3
)

