cmake_minimum_required(VERSION 3.21)
project(LoopProfit LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Merge-resolution note:
# Keep Qt Concurrent enabled because AppController runs LoopEngine in background threads.
# This supersedes the older main-branch variant that omitted Concurrent.
find_package(Qt6 REQUIRED COMPONENTS Core Sql Qml Quick Test Concurrent)

qt_standard_project_setup()

add_library(loopprofit_core
    src/DatabaseManager.cpp
    src/LoopEngine.cpp
    src/AppController.cpp
)

target_include_directories(loopprofit_core PUBLIC src)
target_link_libraries(loopprofit_core PUBLIC Qt6::Core Qt6::Sql Qt6::Concurrent)

# Merge-resolution note: keep compile warnings from codex branch for stricter quality gates.
if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(loopprofit_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

qt_add_executable(LoopProfitApp
    src/main.cpp
)

target_link_libraries(LoopProfitApp PRIVATE loopprofit_core Qt6::Core Qt6::Qml Qt6::Quick)

qt_add_qml_module(LoopProfitApp
    URI LoopProfit
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

enable_testing()

qt_add_executable(test_loopengine
    tests/test_loopengine.cpp
)

target_link_libraries(test_loopengine PRIVATE loopprofit_core Qt6::Core Qt6::Sql Qt6::Test)

add_test(NAME test_loopengine COMMAND test_loopengine)
