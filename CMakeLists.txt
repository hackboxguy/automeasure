cmake_minimum_required(VERSION 3.1)
set(PROJECT_NAME automeasure)
project(${PROJECT_NAME})
add_subdirectory(brbox/sources/lib/lib-settings)
add_subdirectory(brbox/sources/lib/lib-display)
add_subdirectory(brbox/sources/lib/lib-adav-old)
add_subdirectory(brbox/sources/services/sysmgr)
add_subdirectory(brbox/sources/services/hotwire)
add_subdirectory(brbox/sources/services/i2csrv)
add_subdirectory(brbox/sources/services/dispsrv)
add_subdirectory(usb-tempered)
