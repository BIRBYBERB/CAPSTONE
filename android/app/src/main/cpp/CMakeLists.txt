cmake_minimum_required(VERSION 3.4.1)

project(oboe_audio_engine)

# Enable aggressive C++ speed optimizations for ultra-low latency audio
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -flto")

find_package(oboe REQUIRED CONFIG)

add_library(native_audio_engine SHARED native_audio_engine.cpp)

target_link_libraries(native_audio_engine
        oboe::oboe
        log)
