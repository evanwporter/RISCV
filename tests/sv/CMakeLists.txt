# add_subdirectory(renamer)
# add_subdirectory(dispatcher)
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