# CMakeLists.txt for dnfc benchmark_headless_2d (record / mirror)
#
# The canonical source is built INSIDE the dnf-composer tree as an example, not
# from this directory. To build:
#   1. Copy benchmark_headless_2d.cpp into:
#        ../dynamic-neural-field-composer/dynamic-neural-field-composer/examples/
#   2. Register it in examples/CMakeLists.txt:
#        add_example_executable(benchmark_headless_2d benchmark_headless_2d.cpp)
#      (add_example_executable links the imgui include path the dnfc logger
#       header needs; a plain add_executable fails to find log_window.h)
#   3. Build the target from a VS dev shell (vcvars64.bat) using the Ninja
#      build/release cache:
#        cmake --build build/release --target benchmark_headless_2d
#      Output: build/release/examples/benchmark_headless_2d.exe (runs headless,
#      no GUI DLLs needed).
#
# Run: benchmark_headless_2d <output_csv>   (writes timings-dnfc-2d.csv rows)
