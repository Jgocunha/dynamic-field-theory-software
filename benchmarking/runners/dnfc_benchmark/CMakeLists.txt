# CMakeLists.txt for dnfc benchmark_headless
#
# Build as part of the dnfc project (recommended):
#   Copy benchmark_headless.cpp and main_gui.cpp into:
#     ../dynamic-neural-field-composer/dynamic-neural-field-composer/examples/
#   Then add these lines to the examples section of the dnfc CMakeLists.txt:
#
#     add_executable(benchmark_headless "examples/benchmark_headless.cpp")
#     target_link_libraries(benchmark_headless PRIVATE ${CMAKE_PROJECT_NAME})
#
