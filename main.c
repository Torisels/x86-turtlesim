#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define DEBUG 1
//#pragma pack(1)

/*
 * Important constants
 */
#define INPUT_FILE_NAME "input.bin"
#define OUTPUT_FILE_NAME "output.bmp"
#define CONFIG_FILE_NAME "config.txt"
#define CONFIG_BUFFER_LEN 255 //config.txt buffer len (not important)

#define EXIT_CODE_CORRECT 0
#define EXIT_CODE_ERROR_NO_INS 1
#define EXIT_CODE_SET_POS -1
#define EXIT_CODE_ERROR_SET_POS 2

/*
 * Constants for .bmp file such as pixel offset (we use basic windows's standard DIB header)
 * It's size is 14 bytes (bmp basic header) + 40 bytes (DIB header) = 54 bytes.
 */
#define BMP_HEADER_SIZE 54
#define BMP_PIXEL_OFFSET 54
#define BMP_PLANES 1
#define BMP_BPP 24
#define BMP_HORIZONTAL_RES 500 //experimental constant, has to be greater than 0
#define BMP_VERTICAL_RES 500   //experimental constant, has to be greater than 0
#define BMP_DIB_HEADER_SIZE 40

/*
 * Struct for essential turtle information.
 */
typedef struct {
    uint32_t x_pos;
    uint32_t y_pos;
    uint32_t color; // 0x00RRGGBB (red, green, blue)
    uint8_t pen_state; // (0 - up, 1 - down)
    uint8_t direction; // 0 - right, 1 - up, 2 - left, 3 - down
} TurtleContextStruct;

/*
 * Struct for bmp header.
 */
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

/*
 * Initializes bmp_header with default values.
 */
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

/*
 * Reads binary instruction file into memory. Returns pointer. Size has to be passed by reference.
 * Array for binary instructions is dynamically allocated.
 */
unsigned char *read_bin_file(size_t *size) {
    unsigned char *buffer;
    FILE *file;
    file = fopen(INPUT_FILE_NAME, "rb");
    if (file == NULL) {
        printf("Could not read binary file. Exiting!");
        exit(-1);
    }

    fseek(file, 0L, SEEK_END);
    *size = ftell(file);
    rewind(file);

    buffer = malloc(*size);
    if (buffer == NULL) {
        printf("Could not allocate memory for binary file. Exiting!");
        exit(-1);
    }

    fread(buffer, *size, 1, file);
    fclose(file);
    return buffer;
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

/*
 * Writes bmp buffer array into .bmp file.
 */
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

/*
 * Generates empty bitmap for assembler usage. Initializes bitmap with white pixels.
 */
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
    for (int i = 54; i < *output_size; ++i) {
        bitmap[i] = 0xff;
    }
    return bitmap;
}

/*
 * Assembly function to execute turtle command.
 */
extern int exec_turtle_cmd(unsigned char *dest_bitmap, unsigned char *command, TurtleContextStruct *tc);

int main() {

    TurtleContextStruct turtle_context;
    size_t ins_size = 0;
    unsigned char *instructions = read_bin_file(&ins_size);

    if (ins_size == 0) {
        printf("Instruction buffer length cannot be 0. Exiting!");
        exit(1);
    }

    unsigned int dimensions[2] = {0, 0};
    read_config(dimensions);

    if (dimensions[0] == 0 || dimensions[1] == 0) {
        printf("Image's dimensions cannot be 0. Exiting!");
        exit(1);
    }

    size_t bmp_size = 0;
    unsigned char *bmp_buffer = generate_empty_bitmap(dimensions[0], dimensions[1], &bmp_size);

#ifdef DEBUG
    printf("======START OF INITIAL DEBUG INFO=====\n");
    printf("Binary instruction bytes read: %d\n", ins_size);
    printf("Turtle struct size [bytes]: %d\n", sizeof(TurtleContextStruct));
    printf("Header struct size [bytes]: %d\n", sizeof(BmpHeader));
    printf("Width [px]: %d\n", dimensions[0]);
    printf("Height [px]: %d\n", dimensions[1]);
    printf("BMP buffer size [byte]: %d\n", bmp_size);
    printf("======END OF INITIAL DEBUG INFO=====\n");
#endif

    //initialize turtle_context with default values
    turtle_context.x_pos = 0x00;
    turtle_context.y_pos = 0x00;
    turtle_context.color = 0x00;
    turtle_context.pen_state = 0x00;
    turtle_context.direction = 0x00;

    int ins_counter = 0;
    while (ins_counter < ins_size) {
        int result = exec_turtle_cmd(bmp_buffer, instructions + ins_counter, &turtle_context);

#ifdef DEBUG
        printf("XPOS: %d | YPOS: %d | DIRECTION: %X | COLOR: 0x%X | PEN STATE: %d\n",
               turtle_context.x_pos, turtle_context.y_pos, turtle_context.direction,
               turtle_context.color, turtle_context.pen_state);
#endif
        if (result == EXIT_CODE_SET_POS) {
            ins_counter += 4;
        } else if (result == EXIT_CODE_CORRECT) {
            ins_counter += 2;
        } else if (result == EXIT_CODE_ERROR_NO_INS) {
            printf("During processing of an instruction error occured! Exiting\n");
            exit(result); //we don't know by how much increment so we exit
        } else if (result == EXIT_CODE_ERROR_SET_POS) {
            printf("Desired position out of image's bounds. Proceeding with skip!\n");
            ins_counter += 4;
        } else {
            printf("Incorrect code was returned. Exiting!");
            exit(result);
        }
        printf("\n");
    }


    free(instructions); //deallocate instructions' memory
    write_bytes_to_bmp(bmp_buffer, bmp_size); //save bmp buffer into file
    free(bmp_buffer); //deallocate bmp buffer
    return 0;         //exit normally
}
