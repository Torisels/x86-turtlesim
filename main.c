#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>


#define INPUT_FILE_NAME "input.bin"
struct TurtleContextStruct {
    int x_pos;
    int y_pos;
    uint8_t pen_state;
    uint8_t pen_red;
    uint8_t pen_green;
    uint8_t pen_blue;
};

unsigned int read_bin_file(unsigned char* buffer) {
    FILE *file;
    file = fopen(INPUT_FILE_NAME, "rb");  // r for read, b for binary
    fseek(file, 0L, SEEK_END);
    int f_size = ftell(file);
    rewind(file);

    buffer = (unsigned char*) malloc(f_size);
    if (buffer == NULL)
    {
        printf("Could not allocate memory for binary file. Exiting!");
        exit(-1);
    }

    size_t read_bytes = fread(buffer, f_size, 1, file);
    fclose(file);
    return read_bytes;
}


extern int exec_turtle_cmd(unsigned char *dest_bitmap, unsigned char *command, struct TurtleContextStruct *tc);

int main() {

    struct TurtleContextStruct turtle_context;
    unsigned char* instructions = 0;

    size_t result = read_bin_file(instructions);
    free(instructions);
    printf("bytes read: %d", result);
    return 0;
}
