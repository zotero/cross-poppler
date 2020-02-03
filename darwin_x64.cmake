set(CMAKE_SYSTEM_NAME Darwin)

file(GLOB CMAKE_C_COMPILER  /usr/osxcross/bin/x86_64-apple-darwin*-cc)
file(GLOB CMAKE_CXX_COMPILER /usr/osxcross/bin/x86_64-apple-darwin*-c++)

set(CMAKE_FIND_ROOT_PATH /usr/osxcross/bin)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
