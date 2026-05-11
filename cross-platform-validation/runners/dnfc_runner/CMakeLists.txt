# CMakeLists.txt for cross_platform_validation_runner
#
# This runner must be built as part of the dnf-composer project.
#
# Option A (recommended): copy main.cpp into
#   ../dynamic-neural-field-composer/dynamic-neural-field-composer/examples/
#   and add the following lines to the examples section of the dnfc CMakeLists.txt:
#
#     add_executable(cross_platform_validation_runner
#         "examples/cross_platform_validation_runner.cpp")