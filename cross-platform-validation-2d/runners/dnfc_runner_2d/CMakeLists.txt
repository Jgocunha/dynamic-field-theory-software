# CMakeLists.txt for cross_platform_validation_runner_2d
#
# This runner must be built as part of the dnf-composer project (it links the
# dnf_composer library and uses the 2D elements + SimulationFileManager).
#
# To build: copy cross_platform_validation_runner_2d.cpp into
#   C:/dev-files/dynamic-neural-field-composer/dynamic-neural-field-composer/examples/
# and register it in that examples/CMakeLists.txt alongside the other examples:
#
#     add_example_executable(cross_platform_validation_runner_2d
#         cross_platform_validation_runner_2d.cpp)
#
# Then build the dnf-composer project. Run:
#   cross_platform_validation_runner_2d <simulations/dnfc> <data/dnfc>
# Defaults point at ../cross-platform-validation-2d/{simulations,data}/dnfc.
