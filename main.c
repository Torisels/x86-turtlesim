#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define DEBUG 1

#define INPUT_FILE_NAME "input.bin"
#define OUTPUT_FILE_NAME "output.bmp"
#define CONFIG_FILE_NAME "config.txt"
#define CONFIG_BUFFER_LEN 255

#define BMP_HEADER_SIZE 54
#define BMP_PIXEL_OFFSET 54
#define BMP_PLANES 1
#define BMP_BPP 24
#define BMP_HORIZONTAL_RES 2000
#define BMP_VERTICAL_RES 2000
#define BMP_DIB_HEADER_SIZE 40

typedef struct {
    uint32_t x_pos;
    uint32_t y_pos;
    uint32_t color;
    uint8_t pen_state;
} TurtleContextStruct;

typedef struct {
    unsigned char sig_0;
    unsigned char sig_1;
    uint32_t size;
    uint32_t reserved;
    uint32_t pixel_offset;
    uint32_t header_size;
    uint32_t width;
    uint32_t height;
    uint16_t planes;
    uint16_t bpp_type;
    uint32_t compression;
    uint32_t image_size;
    uint32_t horizontal_res;
    uint32_t vertical_res;
    uint32_t color_palette;
    uint32_t important_colors;
} BmpHeader;

void init_bmp_header(BmpHeader *header) {
    header->sig_0 = 'B';
    header->sig_1 = 'M';
    header->reserved = 0;
    header->pixel_offset = BMP_PIXEL_OFFSET;
    header->header_size = BMP_DIB_HEADER_SIZE;
    header->planes = BMP_PLANES;
    header->bpp_type = BMP_BPP;
    header->compression = 0;
    header->image_size = 0;
    header->horizontal_res = BMP_HORIZONTAL_RES;
    header->vertical_res = BMP_VERTICAL_RES;
    header->color_palette = 0;
    header->important_colors = 0;
}

unsigned read_bin_file(unsigned char **buffer) {
    FILE *file;
    file = fopen(INPUT_FILE_NAME, "rb");
    if (file == NULL) {
        printf("Could not read binary file. Exiting!");
        exit(-1);
    }

    fseek(file, 0L, SEEK_END);
    int f_size = ftell(file);
    rewind(file);

    *buffer = malloc(f_size);
    if (*buffer == NULL) {
        printf("Could not allocate memory for binary file. Exiting!");
        exit(-1);
    }

    fread(*buffer, f_size, 1, file);
    fclose(file);
    return f_size;
}

/*
 * Reads width and height from config.txt file for .bmp. Config has to contain 2 lines.
 * First is width, second is height [px].
 */
void read_config(unsigned int *dimensions) {
    FILE *file;
    char buffer[CONFIG_BUFFER_LEN];

    file = fopen(CONFIG_FILE_NAME, "r");
    if (file == NULL) {
        printf("Could not read config file. Exiting!");
        exit(-1);
    }

    unsigned int i = 0;
    while (fgets(buffer, CONFIG_BUFFER_LEN, file)) {
        dimensions[i] = strtol(buffer, NULL, 10);
        ++i;
    }

    fclose(file);
}

void write_bytes_to_bmp(unsigned char *buffer, size_t size) {
    FILE *file;

    file = fopen(OUTPUT_FILE_NAME, "wb");
    if (file == NULL) {
        printf("Could not open output file. Exiting!");
        exit(-1);
    }

    fwrite(buffer, 1, size, file);
    fclose(file);
}

unsigned char *generate_empty_bitmap(unsigned int width, unsigned int height, size_t *output_size) {
    unsigned int row_size = (width * 3 + 3) & ~3;
    *output_size = row_size * height + BMP_HEADER_SIZE;
    unsigned char *bitmap = (unsigned char *) malloc(*output_size);

    BmpHeader header;
    init_bmp_header(&header);
    header.size = *output_size;
    header.width = width;
    header.height = height;

    memcpy(bitmap, &header, BMP_HEADER_SIZE);
    for (int i = 54; i<*output_size;++i)
    {
        bitmap[i] = 0xff;
    }
    return bitmap;
}


extern int exec_turtle_cmd(unsigned char *dest_bitmap, unsigned char *command, TurtleContextStruct *tc);

int main() {

    TurtleContextStruct turtle_context;
    unsigned char *instructions;
    size_t ins_size = read_bin_file(&instructions);

    unsigned int dimensions[2] = {0, 0};
    read_config(dimensions);

    size_t bmp_size = 0;
    unsigned char *bmp_buffer = generate_empty_bitmap(dimensions[0], dimensions[1], &bmp_size);


#ifdef DEBUG
    printf("Binary bytes read: %d\n", ins_size);
    printf("Turtle struct size [bytes]: %d\n", sizeof(TurtleContextStruct));
    printf("Header struct size [bytes]: %d\n", sizeof(BmpHeader));
    printf("Width [px]: %d\n", dimensions[0]);
    printf("Height [px]: %d\n", dimensions[1]);
    printf("BMP byte size: %d\n", bmp_size);
#endif
    int ins_counter = 0;
    turtle_context.x_pos = 0x00;
    turtle_context.y_pos = 0x00;
    turtle_context.color = 0xFF;
    while(ins_counter < ins_size){
        int result = exec_turtle_cmd(bmp_buffer, instructions, &turtle_context);
        printf("CMD result code: %d", result);
        break;
        //        ins_counter +=2;
    }

    printf("XPOS: %d\n", turtle_context.x_pos);
    printf("YPOS: %d\n", turtle_context.y_pos);
    free(instructions);
    write_bytes_to_bmp(bmp_buffer, bmp_size);
    free(bmp_buffer);
    return 0;
}
