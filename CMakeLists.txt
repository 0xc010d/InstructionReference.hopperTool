cmake_minimum_required(VERSION 3.0)

set(PRODUCT_NAME InstructionReference)

project(${PRODUCT_NAME})

set(HOPPER_SDK_PATH ${CMAKE_SOURCE_DIR}/HopperSDK/include)
set(HOPPER_PLUGINS_PATH "~/Library/Application Support/Hopper/Plugins")
set(HOPPER_PLUGIN_TOOL_DIRNAME Tools)
set(HOPPER_PLUGIN_TOOL_EXTENSION hopperTool)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin)
set(CMAKE_INSTALL_PREFIX ${HOPPER_PLUGINS_PATH} CACHE PATH "Plugins install prefix" FORCE)

include_directories("${HOPPER_SDK_PATH}")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -fobjc-arc")

set(SOURCE_FILES InstructionReferenceTool.mm)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/intel.db
    COMMAND sqlite3 ${CMAKE_CURRENT_BINARY_DIR}/intel.db < ${CMAKE_CURRENT_SOURCE_DIR}/intel.sql
    DEPENDS intel.sql
)
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/arm.db
    COMMAND sqlite3 ${CMAKE_CURRENT_BINARY_DIR}/arm.db < ${CMAKE_CURRENT_SOURCE_DIR}/arm.sql
    DEPENDS arm.sql
)
set(RESOURCE_FILES ${CMAKE_CURRENT_BINARY_DIR}/intel.db ${CMAKE_CURRENT_BINARY_DIR}/arm.db)

add_library(
    ${PRODUCT_NAME} MODULE
    ${SOURCE_FILES} ${RESOURCE_FILES}
)
set_source_files_properties(
    ${RESOURCE_FILES}
    PROPERTIES MACOSX_PACKAGE_LOCATION Resources
    GENERATED true
)
set_target_properties(
    ${PRODUCT_NAME} PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION ${HOPPER_PLUGIN_TOOL_EXTENSION}
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
)
target_link_libraries(${PRODUCT_NAME} "-framework Foundation" sqlite3)

install(
    TARGETS ${PRODUCT_NAME}
    LIBRARY DESTINATION ${HOPPER_PLUGIN_TOOL_DIRNAME}
)

#set(CMAKE_VERBOSE_MAKEFILE true)