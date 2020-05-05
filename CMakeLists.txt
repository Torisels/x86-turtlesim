cmake_minimum_required(VERSION 3.15)
project(x86_turtlesim C)

set(CMAKE_C_STANDARD 99)

enable_language(ASM_NASM)
set(CMAKE_ASM_NASM_COMPILE_OBJECT "<CMAKE_ASM_NASM_COMPILER> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>")


add_compile_options(
        "$<$<COMPILE_LANGUAGE:ASM_NASM>:-f $<IF:$<BOOL:$<TARGET_PROPERTY:NASM_OBJ_FORMAT>>, \
    $<TARGET_PROPERTY:NASM_OBJ_FORMAT>, ${CMAKE_ASM_NASM_OBJECT_FORMAT}>>"
)


set(CMAKE_ASM_NASM_FLAGS_DEBUG "-g -Fdwarf")
add_executable(x86_turtlesim main.c program.asm)
set_target_properties(x86_turtlesim PROPERTIES NASM_OBJ_FORMAT elf32)