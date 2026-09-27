cmake_minimum_required(VERSION 3.4.1)

project(oboe_audio_engine)

find_package(oboe REQUIRED CONFIG)

add_library(native_audio_engine SHARED native_audio_engine.cpp)

target_link_libraries(native_audio_engine
        oboe::oboe
        log)
