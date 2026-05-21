set(RV_TESTS_DIR ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(common)
add_subdirectory(ooo)

get_target_property(RV_TESTBENCHES rv_rtl INTERFACE_RV_TESTBENCHES)

set(RV_TESTBENCHES_F_CONTENT
"${RV_TESTBENCHES}
")

string(REPLACE ";" "\n" RV_TESTBENCHES_F_CONTENT "${RV_TESTBENCHES_F_CONTENT}")

set(RV_COMMAND_FILE ${CMAKE_CURRENT_BINARY_DIR}/testbenches.f)
file(WRITE ${RV_COMMAND_FILE} "${RV_TESTBENCHES_F_CONTENT}\n")
file(APPEND ${RV_COMMAND_FILE} "+incdir+${CMAKE_CURRENT_SOURCE_DIR}\n")
file(APPEND ${RV_COMMAND_FILE} "+define+VCD_DIR=\"${CMAKE_CURRENT_SOURCE_DIR}\"\n")

include(ExternalProject)

ExternalProject_Add(riscv-doom
    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/doom
    BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/doom/build

    CMAKE_ARGS
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_CURRENT_SOURCE_DIR}/riscv-toolchain.cmake
        -DCMAKE_BUILD_TYPE=$<CONFIG>
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

    BUILD_ALWAYS TRUE
    INSTALL_COMMAND ""
)

add_executable(test_doom)

target_sources(test_doom PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/doom/main.cpp
)

add_dependencies(test_doom riscv-doom)

ExternalProject_Get_Property(riscv-doom BINARY_DIR)

add_custom_command(
    TARGET test_doom POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${BINARY_DIR}/test_doom.elf
        $<TARGET_FILE_DIR:test_doom>/test_doom.elf
)

# include(ExternalProject)

# ExternalProject_Add(riscv-bf
#     SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/bf
#     BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/bf/build

#     CMAKE_ARGS
#         -DCMAKE_TOOLCHAIN_FILE=${CMAKE_CURRENT_SOURCE_DIR}/riscv-toolchain.cmake
#         -DCMAKE_BUILD_TYPE=$<CONFIG>
#         -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

#     BUILD_ALWAYS TRUE
#     INSTALL_COMMAND ""
# )

# add_executable(test_bf)

# target_sources(test_bf PRIVATE
#     ${CMAKE_CURRENT_SOURCE_DIR}/bf/main.cpp
# )

# add_dependencies(test_bf riscv-bf)

# ExternalProject_Get_Property(riscv-bf BINARY_DIR)

# add_custom_command(
#     TARGET test_bf POST_BUILD
#     COMMAND ${CMAKE_COMMAND} -E copy_if_different
#         ${BINARY_DIR}/guest.elf
#         $<TARGET_FILE_DIR:test_bf>/guest.elf
# )