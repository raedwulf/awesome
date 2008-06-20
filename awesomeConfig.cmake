SET(PROJECT_AWE_NAME awesome)
SET(PROJECT_AWECLIENT_NAME awesome-client)
SET(VERSION 3)
SET(VERSION_MAJOR ${VERSION})
SET(VERSION_MINOR 0)
SET(VERSION_PATCH 0)

PROJECT(${PROJECT_AWE_NAME})

SET(CMAKE_BUILD_TYPE RELEASE)

OPTION(WITH_DBUS "build with D-BUS" ON)
OPTION(WITH_IMLIB "build with Imlib" ON)

ADD_DEFINITIONS(-std=gnu99 -ggdb3 -fno-strict-aliasing -Wall -Wextra
    -Wchar-subscripts -Wundef -Wshadow -Wcast-align -Wwrite-strings
    -Wsign-compare -Wunused -Wno-unused-parameter -Wuninitialized -Winit-self
    -Wpointer-arith -Wredundant-decls -Wformat-nonliteral
    -Wno-format-zero-length -Wmissing-format-attribute)

# If this is a git repository...
IF(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/.git/HEAD)
    # ...update version
    FIND_PROGRAM(GIT_EXECUTABLE git)
    IF(GIT_EXECUTABLE)
        EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} describe
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            OUTPUT_VARIABLE VERSION
            OUTPUT_STRIP_TRAILING_WHITESPACE)
    ENDIF()
ENDIF()

# Check for doxygen
INCLUDE(FindDoxygen)
INCLUDE(FindPkgConfig)
INCLUDE(UsePkgConfig)

SET(AWE_COMMON_DIR common)
SET(AWE_LAYOUT_DIR layouts)
SET(AWE_WIDGET_DIR widgets)

# Use pkgconfig to get most of the libraries
pkg_check_modules(AWE_MOD REQUIRED
    glib-2.0
    cairo
    pango
    gdk-2.0>=2.2
    gdk-pixbuf-2.0>=2.2
    xcb
    xcb-event
    xcb-randr
    xcb-xinerama
    xcb-shape
    xcb-aux
    xcb-atom
    xcb-keysyms
    xcb-render
    xcb-icccm
    cairo-xcb)

# Check for readline, ncurse and libev
FIND_LIBRARY(LIB_READLINE readline)
FIND_LIBRARY(LIB_NCURSES ncurses)
FIND_LIBRARY(LIB_EV ev)

# Check for optional libs
IF(WITH_DBUS)
    pkg_check_modules(DBUS dbus-1)
    IF(DBUS_FOUND)
        ADD_DEFINITIONS(-DWITH_DBUS)
        SET(AWE_MOD_LIBRARIES ${AWE_MOD_LIBRARIES} ${DBUS_LIBRARIES})
        SET(AWE_MOD_INCLUDE_DIRS ${AWE_MOD_INCLUDE_DIRS} ${DBUS_INCLUDE_DIRS})
    ELSE()
        SET(WITH_DBUS OFF)
        MESSAGE(STATUS "DBUS not found. Disabled.")
    ENDIF()
ENDIF()

IF(WITH_IMLIB)
    pkg_check_modules(IMLIB imlib2)
    IF(IMLIB_FOUND)
        ADD_DEFINITIONS(-DWITH_IMLIB)
        SET(AWE_MOD_LIBRARIES ${AWE_MOD_LIBRARIES} ${IMLIB_LIBRARIES})
        SET(AWE_MOD_INCLUDE_DIRS ${AWE_MOD_INCLUDE_DIRS} ${IMLIB_INCLUDE_DIRS})
    ELSE()
        SET(WITH_IMLIB OFF)
        MESSAGE(STATUS "Imlib not found. Disabled.")
    ENDIF()
ENDIF()

# Check for lua5.1
FIND_PATH(LUA_INC_DIR lua.h
    /usr/include
    /usr/include/lua5.1
    /usr/local/include/lua5.1)

FIND_LIBRARY(LUA_LIB NAMES lua5.1 lua
    /usr/lib
    /usr/lib/lua
    /usr/local/lib)

FIND_PROGRAM(LUA_EXECUTABLE lua)

# Error check
IF(NOT LIB_EV)
    MESSAGE( FATAL_ERROR "ev library not found")
ENDIF()

IF(NOT LIB_READLINE)
    MESSAGE(FATAL_ERROR "readline library not found")
ENDIF()

IF(NOT LIB_NCURSES)
    MESSAGE(FATAL_ERROR "ncurse library not found")
ENDIF()

IF(NOT LUA_LIB)
    MESSAGE(FATAL_ERROR "lua library not found")
ENDIF()

IF(DOXYGEN_EXECUTABLE)
    ADD_CUSTOM_TARGET(doc ${DOXYGEN_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/awesome.doxygen)
ENDIF()

# Check for programs needed for man pages
FIND_PROGRAM(ASCIIDOC_EXECUTABLE asciidoc)
FIND_PROGRAM(XMLTO_EXECUTABLE xmlto)
FIND_PROGRAM(GZIP_EXECUTABLE gzip)

IF(ASCIIDOC_EXECUTABLE AND XMLTO_EXECUTABLE AND GZIP_EXECUTABLE)
    SET(AWESOME_GENERATE_MAN TRUE)
ENDIF()

# Set awesome informations and path
IF(DEFINED PREFIX)
    SET(CMAKE_INSTALL_PREFIX ${PREFIX})
ENDIF()
SET(AWESOME_VERSION_INTERNAL devel )
SET(AWESOME_COMPILE_MACHINE  ${CMAKE_SYSTEM_PROCESSOR} )
SET(AWESOME_COMPILE_HOSTNAME $ENV{HOSTNAME} )
SET(AWESOME_COMPILE_BY       $ENV{USER} )
SET(AWESOME_RELEASE          ${VERSION} )
SET(AWESOME_ETC              etc )
SET(AWESOME_SHARE            share )
SET(AWESOME_LUA_LIB_PATH     ${CMAKE_INSTALL_PREFIX}/${AWESOME_SHARE}/${PROJECT_AWE_NAME}/lib )
SET(AWESOME_ICON_PATH        ${CMAKE_INSTALL_PREFIX}/${AWESOME_SHARE}/${PROJECT_AWE_NAME}/icons )
SET(AWESOME_CONF_PATH        ${CMAKE_INSTALL_PREFIX}/${AWESOME_ETC}/${PROJECT_AWE_NAME} )
SET(AWESOME_MAN1_PATH        ${AWESOME_SHARE}/man/man1 )
SET(AWESOME_MAN5_PATH        ${AWESOME_SHARE}/man/man5 )
SET(AWESOME_REL_LUA_LIB_PATH ${AWESOME_SHARE}/${PROJECT_AWE_NAME}/lib )
SET(AWESOME_REL_CONF_PATH    ${AWESOME_ETC}/${PROJECT_AWE_NAME} )
SET(AWESOME_REL_ICON_PATH    ${AWESOME_SHARE}/${PROJECT_AWE_NAME} )

# Configure files.
SET (AWESOME_CONFIGURE_FILES config.h.in
                             awesomerc.lua.in
                             awesome-version-internal.h.in
                             awesome.doxygen.in)

MACRO(a_configure_file file)
    STRING(REGEX REPLACE ".in\$" "" outfile ${file})
    MESSAGE(STATUS "Configuring ${outfile}")
    CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/${file}
                   ${CMAKE_CURRENT_SOURCE_DIR}/${outfile}
                   ESCAPE_QUOTE
                   @ONLY)
ENDMACRO()

FOREACH(file ${AWESOME_CONFIGURE_FILES})
    a_configure_file(${file})
ENDFOREACH()

# Execute some header generator
EXECUTE_PROCESS(COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/build-utils/layoutgen.sh
                OUTPUT_FILE ${CMAKE_CURRENT_SOURCE_DIR}/layoutgen.h
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

EXECUTE_PROCESS(COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/build-utils/widgetgen.sh
                OUTPUT_FILE ${CMAKE_CURRENT_SOURCE_DIR}/widgetgen.h
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# Set the awesome include dir
SET(AWE_INC_DIR ${CMAKE_CURRENT_SOURCE_DIR} ${AWE_MOD_INCLUDE_DIRS} ${LUA_INC_DIR})

SET(CPACK_PACKAGE_NAME                 "${PROJECT_AWE_NAME}")
SET(CPACK_GENERATOR                    "TBZ2")
SET(CPACK_SOURCE_GENERATOR             "TBZ2")
SET(CPACK_SOURCE_IGNORE_FILES          ".git;.*.swp$;.*~;.*patch;.gitignore")
SET(CPACK_PACKAGE_DESCRIPTION_SUMMARY  "A dynamic floating and tiling window manager")
SET(CPACK_PACKAGE_VENDOR               "awesome development team")
SET(CPACK_PACKAGE_DESCRIPTION_FILE     "${CMAKE_CURRENT_SOURCE_DIR}/README")
SET(CPACK_RESOURCE_FILE_LICENSE        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
SET(CPACK_PACKAGE_VERSION_MAJOR        "${VERSION_MAJOR}")
SET(CPACK_PACKAGE_VERSION_MINOR        "${VERSION_MINOR}")
SET(CPACK_PACKAGE_VERSION_PATCH        "${VERSION_PATCH}")

INCLUDE(CPack)

# vim: filetype=cmake:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:encoding=utf-8:textwidth=80