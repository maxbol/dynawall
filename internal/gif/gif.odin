package gif

import "../lzw"
import "base:runtime"
import "core:fmt"
import "core:os"

//odinfmt: disable
DEFAULT_PALETTE := []u8 {
	0,
	0,
	0,
	0,
	0,
	64,
	0,
	0,
	128,
	0,
	0,
	192,
	0,
	32,
	0,
	0,
	32,
	64,
	0,
	32,
	128,
	0,
	32,
	192,
	0,
	64,
	0,
	0,
	64,
	64,
	0,
	64,
	128,
	0,
	64,
	192,
	0,
	96,
	0,
	0,
	96,
	64,
	0,
	96,
	128,
	0,
	96,
	192,
	0,
	128,
	0,
	0,
	128,
	64,
	0,
	128,
	128,
	0,
	128,
	192,
	0,
	160,
	0,
	0,
	160,
	64,
	0,
	160,
	128,
	0,
	160,
	192,
	0,
	192,
	0,
	0,
	192,
	64,
	0,
	192,
	128,
	0,
	192,
	192,
	0,
	224,
	0,
	0,
	224,
	64,
	0,
	224,
	128,
	0,
	224,
	192,
	32,
	0,
	0,
	32,
	0,
	64,
	32,
	0,
	128,
	32,
	0,
	192,
	32,
	32,
	0,
	32,
	32,
	64,
	32,
	32,
	128,
	32,
	32,
	192,
	32,
	64,
	0,
	32,
	64,
	64,
	32,
	64,
	128,
	32,
	64,
	192,
	32,
	96,
	0,
	32,
	96,
	64,
	32,
	96,
	128,
	32,
	96,
	192,
	32,
	128,
	0,
	32,
	128,
	64,
	32,
	128,
	128,
	32,
	128,
	192,
	32,
	160,
	0,
	32,
	160,
	64,
	32,
	160,
	128,
	32,
	160,
	192,
	32,
	192,
	0,
	32,
	192,
	64,
	32,
	192,
	128,
	32,
	192,
	192,
	32,
	224,
	0,
	32,
	224,
	64,
	32,
	224,
	128,
	32,
	224,
	192,
	64,
	0,
	0,
	64,
	0,
	64,
	64,
	0,
	128,
	64,
	0,
	192,
	64,
	32,
	0,
	64,
	32,
	64,
	64,
	32,
	128,
	64,
	32,
	192,
	64,
	64,
	0,
	64,
	64,
	64,
	64,
	64,
	128,
	64,
	64,
	192,
	64,
	96,
	0,
	64,
	96,
	64,
	64,
	96,
	128,
	64,
	96,
	192,
	64,
	128,
	0,
	64,
	128,
	64,
	64,
	128,
	128,
	64,
	128,
	192,
	64,
	160,
	0,
	64,
	160,
	64,
	64,
	160,
	128,
	64,
	160,
	192,
	64,
	192,
	0,
	64,
	192,
	64,
	64,
	192,
	128,
	64,
	192,
	192,
	64,
	224,
	0,
	64,
	224,
	64,
	64,
	224,
	128,
	64,
	224,
	192,
	96,
	0,
	0,
	96,
	0,
	64,
	96,
	0,
	128,
	96,
	0,
	192,
	96,
	32,
	0,
	96,
	32,
	64,
	96,
	32,
	128,
	96,
	32,
	192,
	96,
	64,
	0,
	96,
	64,
	64,
	96,
	64,
	128,
	96,
	64,
	192,
	96,
	96,
	0,
	96,
	96,
	64,
	96,
	96,
	128,
	96,
	96,
	192,
	96,
	128,
	0,
	96,
	128,
	64,
	96,
	128,
	128,
	96,
	128,
	192,
	96,
	160,
	0,
	96,
	160,
	64,
	96,
	160,
	128,
	96,
	160,
	192,
	96,
	192,
	0,
	96,
	192,
	64,
	96,
	192,
	128,
	96,
	192,
	192,
	96,
	224,
	0,
	96,
	224,
	64,
	96,
	224,
	128,
	96,
	224,
	192,
	128,
	0,
	0,
	128,
	0,
	64,
	128,
	0,
	128,
	128,
	0,
	192,
	128,
	32,
	0,
	128,
	32,
	64,
	128,
	32,
	128,
	128,
	32,
	192,
	128,
	64,
	0,
	128,
	64,
	64,
	128,
	64,
	128,
	128,
	64,
	192,
	128,
	96,
	0,
	128,
	96,
	64,
	128,
	96,
	128,
	128,
	96,
	192,
	128,
	128,
	0,
	128,
	128,
	64,
	128,
	128,
	128,
	128,
	128,
	192,
	128,
	160,
	0,
	128,
	160,
	64,
	128,
	160,
	128,
	128,
	160,
	192,
	128,
	192,
	0,
	128,
	192,
	64,
	128,
	192,
	128,
	128,
	192,
	192,
	128,
	224,
	0,
	128,
	224,
	64,
	128,
	224,
	128,
	128,
	224,
	192,
	160,
	0,
	0,
	160,
	0,
	64,
	160,
	0,
	128,
	160,
	0,
	192,
	160,
	32,
	0,
	160,
	32,
	64,
	160,
	32,
	128,
	160,
	32,
	192,
	160,
	64,
	0,
	160,
	64,
	64,
	160,
	64,
	128,
	160,
	64,
	192,
	160,
	96,
	0,
	160,
	96,
	64,
	160,
	96,
	128,
	160,
	96,
	192,
	160,
	128,
	0,
	160,
	128,
	64,
	160,
	128,
	128,
	160,
	128,
	192,
	160,
	160,
	0,
	160,
	160,
	64,
	160,
	160,
	128,
	160,
	160,
	192,
	160,
	192,
	0,
	160,
	192,
	64,
	160,
	192,
	128,
	160,
	192,
	192,
	160,
	224,
	0,
	160,
	224,
	64,
	160,
	224,
	128,
	160,
	224,
	192,
	192,
	0,
	0,
	192,
	0,
	64,
	192,
	0,
	128,
	192,
	0,
	192,
	192,
	32,
	0,
	192,
	32,
	64,
	192,
	32,
	128,
	192,
	32,
	192,
	192,
	64,
	0,
	192,
	64,
	64,
	192,
	64,
	128,
	192,
	64,
	192,
	192,
	96,
	0,
	192,
	96,
	64,
	192,
	96,
	128,
	192,
	96,
	192,
	192,
	128,
	0,
	192,
	128,
	64,
	192,
	128,
	128,
	192,
	128,
	192,
	192,
	160,
	0,
	192,
	160,
	64,
	192,
	160,
	128,
	192,
	160,
	192,
	192,
	192,
	0,
	192,
	192,
	64,
	192,
	192,
	128,
	192,
	192,
	192,
	192,
	224,
	0,
	192,
	224,
	64,
	192,
	224,
	128,
	192,
	224,
	192,
	224,
	0,
	0,
	224,
	0,
	64,
	224,
	0,
	128,
	224,
	0,
	192,
	224,
	32,
	0,
	224,
	32,
	64,
	224,
	32,
	128,
	224,
	32,
	192,
	224,
	64,
	0,
	224,
	64,
	64,
	224,
	64,
	128,
	224,
	64,
	192,
	224,
	96,
	0,
	224,
	96,
	64,
	224,
	96,
	128,
	224,
	96,
	192,
	224,
	128,
	0,
	224,
	128,
	64,
	224,
	128,
	128,
	224,
	128,
	192,
	224,
	160,
	0,
	224,
	160,
	64,
	224,
	160,
	128,
	224,
	160,
	192,
	224,
	192,
	0,
	224,
	192,
	64,
	224,
	192,
	128,
	224,
	192,
	192,
	224,
	224,
	0,
	224,
	224,
	64,
	224,
	224,
	128,
	224,
	224,
	192,
}


// /* gif_writer.c */
// struct gif_writer {
//   struct {
//     enum gif_source_type dst_type;
//     union {
//       struct darray *ptr;
//       FILE *file;
//     } dst;
//   } meta;
//   unsigned int width;
//   unsigned int height;
//   unsigned int n_colors;
//   unsigned char code_size;
//   unsigned char *palette;
// };

// enum gif_source_type {
//   GIF_FILE,
//   GIF_BUFFER
// };

// enum gif_tag {
//   TAG_GRAPHIC_EXTENSION = 0x21,
//   TAG_GRAPHIC_CONTROL_LABEL = 0xf9,
//   TAG_COMMENT_LABEL = 0xfe,
//   TAG_APPLICATION_LABEL = 0xff,
//   TAG_PLAIN_TEXT_LABEL = 0x01,
//   TAG_IMAGE_DESCRIPTOR = 0x2c,
//   TAG_TRAILER = 0x3b
// };

GifTag :: enum (u8) {
	TagGraphicExtension    = 0x21,
	TagGraphicControlLabel = 0xf9,
	TagCommentLabel        = 0xfe,
	TagApplicationLabel    = 0xff,
	TagPlainTextLabel      = 0x01,
	TagImageDescriptor     = 0x2c,
	TagTrailer             = 0x3b,
}

GifSourceType :: enum {
	GifFile,
	GifBuffer,
}

GifWriterMetaDst :: union {
	[dynamic]u8,
	os.Handle,
}

// struct gif_opts {
//   unsigned int delay;
//   unsigned char flags;
//   unsigned char trans_index;
// };

GifOpts :: struct {
	delay:       uint,
	flags:       u8,
	trans_index: u8,
}

GifWriterMeta :: struct {
	dst: GifWriterMetaDst,
}

GifWriter :: struct {
	meta:      GifWriterMeta,
	width:     uint,
	height:    uint,
	n_colors:  uint,
	code_size: u8,
	palette:   []u8,
}

// int gifw_init(struct gif_writer *g,
//               unsigned char code_size,
//               unsigned char *palette,
//               unsigned int width,
//               unsigned int height) {
//   if (!g) return -1;
//   g->width = width;
//   g->height = height;
//   if (palette) {
//     g->code_size = code_size;
//     g->n_colors = 1u << g->code_size;
//     g->palette = palette;
//   } else {
//     g->code_size = 8;
//     g->n_colors = 256;
//     g->palette = DEFAULT_PALETTE;
//   }
//   g->meta.dst_type = GIF_BUFFER;
//   g->meta.dst.ptr = danew(g->width * g->height);
//   if (!g->meta.dst.ptr) return -1;
//   header(g);
//   logical_screen(g);
//   netscape_loop(g);
//   return 0;
// }
//

// static void header(struct gif_writer *g) {
// #define GIF_HEADER_SIZE 6
//
//   unsigned char version[] = { 'G', 'I', 'F', '8', '9', 'a' };
//
//   write_bytes(g, GIF_HEADER_SIZE, version);
//
// #undef GIF_HEADER_SIZE
// }
//

// static void write_bytes(struct gif_writer *g,
//                         size_t len,
//                         unsigned char *bytes) {
//   if (g->meta.dst_type == GIF_FILE) {
//     fwrite(bytes, len, 1, g->meta.dst.file);
//   } else {
//     dapushn(g->meta.dst.ptr, len, bytes);
//   }
// }
//

// static void logical_screen(struct gif_writer *g) {
// #define LOGICAL_SCREEN_DESCRIPTOR_SIZE 7
// #define GLOBAL_COLOR_TABLE_FLAG 0x80
// #define GLOBAL_COLOR_TABLE_SIZE 0x07
//
//   unsigned char lsd[LOGICAL_SCREEN_DESCRIPTOR_SIZE];
//
//   WRITE2BYTES(lsd, g->width);
//   WRITE2BYTES(lsd + 2, g->height);
//   /* color table flag */
//   lsd[4] = GLOBAL_COLOR_TABLE_FLAG;
//   /* color table size */
//   lsd[4] |= (unsigned char) (g->code_size - 1);
//   /* background color index */
//   lsd[5] = 0;
//   /* aspect */
//   lsd[6] = 0;
//   write_bytes(g, LOGICAL_SCREEN_DESCRIPTOR_SIZE, lsd);
//   /* write the palette: n_colors * 3 bytes (1 byte per channel RGB) */
//   write_bytes(g, g->n_colors * 3u, g->palette);
//
// #undef LOGICAL_SCREEN_DESCRIPTOR_SIZE
// #undef GLOBAL_COLOR_TABLE_FLAG
// #undef GLOBAL_COLOR_TABLE_SIZE
// }
//

// static void netscape_loop(struct gif_writer *g) {
// #define APPLICATION_HEADER_SIZE 12
//
//   unsigned char header[APPLICATION_HEADER_SIZE];
//
//   write_byte(g, TAG_GRAPHIC_EXTENSION);
//   write_byte(g, TAG_APPLICATION_LABEL);
//   /* block size */
//   header[0] = APPLICATION_HEADER_SIZE - 1;
//   sprintf((char *) (header + 1), "NETSCAPE");
//   header[9] = '2';
//   header[10] = '.';
//   header[11] = '0';
//   write_bytes(g, APPLICATION_HEADER_SIZE, header);
//   /* subblock size */
//   write_byte(g, 3);
//   /* subblock id */
//   write_byte(g, 1);
//   /* 2-byte loop count (0 = infinite) */
//   write_byte(g, 0);
//   write_byte(g, 0);
//   /* terminator */
//   write_byte(g, 0);
//
// #undef APPLICATION_HEADER_SIZE
// }
//

// static void write_byte(struct gif_writer *g, unsigned char byte) {
//   write_bytes(g, 1, &byte);
// }
//

// void gifw_push(struct gif_writer *g,
//                struct gif_opts *opts,
//                unsigned int left,
//                unsigned int top,
//                unsigned int width,
//                unsigned int height,
//                unsigned char *img) {
//   if (!g) return;
//   if (opts) graphic_control(g, opts);
//   image_descriptor(g, left, top, width, height);
//   write_image(g, width, height, img);
//   return;
//
// #undef CODE_SIZE_DEFAULT
// }
//

// static void graphic_control(struct gif_writer *g, struct gif_opts *opts) {
// #define GRAPHIC_CONTROL_HEADER_SIZE 5
//
//   unsigned char header[GRAPHIC_CONTROL_HEADER_SIZE];
//
//   write_byte(g, TAG_GRAPHIC_EXTENSION);
//   write_byte(g, TAG_GRAPHIC_CONTROL_LABEL);
//   /* block size */
//   header[0] = GRAPHIC_CONTROL_HEADER_SIZE - 1;
//   header[1] = opts->flags;
//   WRITE2BYTES(header + 2, opts->delay);
//   header[4] = opts->trans_index;
//   write_bytes(g, GRAPHIC_CONTROL_HEADER_SIZE, header);
//   /* terminator */
//   write_byte(g, 0);
//
// #undef GRAPHIC_CONTROL_HEADER_SIZE
// }
//

// static void image_descriptor(struct gif_writer *g,
//                              unsigned int left,
//                              unsigned int top,
//                              unsigned int width,
//                              unsigned int height) {
// #define IMAGE_DESCRIPTOR_SIZE 9
//
//   unsigned char header[IMAGE_DESCRIPTOR_SIZE];
//
//   write_byte(g, TAG_IMAGE_DESCRIPTOR);
//   WRITE2BYTES(header + 0, left);
//   WRITE2BYTES(header + 2, top);
//   WRITE2BYTES(header + 4, width);
//   WRITE2BYTES(header + 6, height);
//   /* flags */
//   header[8] = 0;
//   write_bytes(g, IMAGE_DESCRIPTOR_SIZE, header);
//
// #undef IMAGE_DESCRIPTOR_SIZE
// }
//

// static int write_image(struct gif_writer *g,
//                        unsigned int width,
//                        unsigned int height,
//                        unsigned char *img) {
//   unsigned char *indexed_img, *compr, *tmp;
//   unsigned int i, j;
//   size_t len;
//
//   indexed_img = malloc(width * height);
//   if (!indexed_img) return -1;
//   for (i = 0; i < height; ++i) {
//     for (j = 0; j < width; ++j) {
//       unsigned char red, green, blue;
//       size_t index;
//
//       index = (i * width) + j;
//       red = img[(3 * index) + 0];
//       green = img[(3 * index) + 1];
//       blue = img[(3 * index) + 2];
//       indexed_img[(i * width) + j] = calc_color(g, red, green, blue);
//     }
//   }
//   lzw_compress_gif(g->code_size, width * height, indexed_img, &len, &compr);
//   tmp = compr;
//   write_byte(g, g->code_size);
//   while (len > 255) {
//     write_byte(g, 255);
//     write_bytes(g, 255, tmp);
//     tmp += 255;
//     len -= 255;
//   }
//   write_byte(g, (unsigned char) len);
//   write_bytes(g, len, tmp);
//   write_byte(g, 0);
//   free(compr);
//   free(indexed_img);
//   return 0;
// }
//

WriteImageError :: union #shared_nil {
	runtime.Allocator_Error,
	lzw.CompressError,
}

// static unsigned char calc_color(struct gif_writer *gw,
//                                 unsigned char r,
//                                 unsigned char g,
//                                 unsigned char b) {
//   unsigned int i;
//   struct {
//     unsigned long min;
//     unsigned char index;
//   } result;
//
//   /* max out the value */
//   result.min = ~0UL;
//   result.index = 0;
//   /* cycle through all colors in the palette */
//   for (i = 0; i < gw->n_colors; ++i) {
//     /* palette RGB */
//     unsigned char pr, pg, pb;
//     unsigned int index, delta;
//
//     index = 3 * i;
//     pr = gw->palette[index + 0];
//     pg = gw->palette[index + 1];
//     pb = gw->palette[index + 2];
//     delta = (unsigned int) ((pr - r) * (pr - r));
//     delta += (unsigned int) ((pg - g) * (pg - g));
//     delta += (unsigned int) ((pb - b) * (pb - b));
//     if (delta < result.min) {
//       result.min = delta;
//       result.index = (unsigned char) i;
//     }
//   }
//   return result.index;
// }
//

// void gifw_end(struct gif_writer *g, size_t *out_len, unsigned char **out_img) {
//   if (!g)
//     return;
//   write_byte(g, TAG_TRAILER);
//   *out_len = dalen(g->meta.dst.ptr);
//   *out_img = dapeel(g->meta.dst.ptr);
// }

calc_color :: proc(gw: ^GifWriter, r: u8, g: u8, b: u8) -> u8 {
	i: uint
	result: struct {
		min:   u32,
		index: u8,
	}

	result.min = ~u32(0)
	result.index = 0

	for i = 0; i < gw.n_colors; i += 1 {
		pr, pg, pb: u8
		index, delta: uint

		index = 3 * i
		pr = gw.palette[index + 0]
		pg = gw.palette[index + 1]
		pb = gw.palette[index + 2]
		delta = uint((pr - r) * (pr - r))
		delta += uint((pg - g) * (pg - g))
		delta += uint((pb - b) * (pb - b))

		if u32(delta) < result.min {
			result.min = u32(delta)
			result.index = u8(i)
		}
	}
	return result.index
}

graphic_control :: proc(g: ^GifWriter, opts: ^GifOpts) {
	GRAPHIC_CONTROL_HEADER_SIZE :: 5

	header: [GRAPHIC_CONTROL_HEADER_SIZE]u8

	write_byte(g, u8(GifTag.TagGraphicExtension))
	write_byte(g, u8(GifTag.TagGraphicControlLabel))

	// Block size
	header[0] = GRAPHIC_CONTROL_HEADER_SIZE - 1
	header[1] = opts.flags
	write_u16(header[2:], u16(opts.delay))
	header[4] = opts.trans_index

	write_bytes(g, header[:])

	// Terminator
	write_byte(g, 0)
}

header :: proc(g: ^GifWriter) {
	GIF_HEADER_SIZE :: #config(GIF_HEADER_SIZE, 6)

	version := []u8{'G', 'I', 'F', '8', '9', 'a'}

	write_bytes(g, version)
}

image_descriptor :: proc(g: ^GifWriter, left: uint, top: uint, width: uint, height: uint) {
	IMAGE_DESCRIPTOR_SIZE :: 9

	header: [IMAGE_DESCRIPTOR_SIZE]u8

	write_byte(g, u8(GifTag.TagImageDescriptor))
	write_u16(header[0:2], u16(left))
	write_u16(header[2:4], u16(top))
	write_u16(header[4:6], u16(width))
	write_u16(header[6:8], u16(height))

	header[8] = 0

	write_bytes(g, header[:])
}

logical_screen :: proc(g: ^GifWriter) {
	LOGICAL_SCREEN_DESCRIPTOR_SIZE :: 7
	GLOBAL_COLOR_TABLE_FLAG :: 0x80
	GLOBAL_COLOR_TABLE_SIZE :: 0x07

	lsd: [LOGICAL_SCREEN_DESCRIPTOR_SIZE]u8

	write_u16(lsd[:2], u16(g.width))
	write_u16(lsd[2:4], u16(g.height))

	lsd[4] = GLOBAL_COLOR_TABLE_FLAG
	fmt.println("g.code_size = ", g.code_size)
	lsd[4] |= u8(g.code_size - 1)
	// Bg color index
	lsd[5] = 0
	// Aspect
	lsd[6] = 0

	// Write the logical screen descriptor header
	write_bytes(g, lsd[:])

	// Actually write the color table
	write_bytes(g, g.palette)
}

netscape_loop :: proc(g: ^GifWriter) {
	APPLICATION_HEADER_SIZE :: 12

	header: [APPLICATION_HEADER_SIZE]u8

	write_byte(g, u8(GifTag.TagGraphicExtension))
	write_byte(g, u8(GifTag.TagApplicationLabel))

	header[0] = APPLICATION_HEADER_SIZE - 1
	fmt.bprint(header[1:], "NETSCAPE")
	header[9] = '2'
	header[10] = '.'
	header[11] = '0'
	write_bytes(g, header[:])

	// Subblock size
	write_byte(g, 3)

	// Subblock ID
	write_byte(g, 1)

	// 2-byte loop count (0 = infinite)
	write_byte(g, 0)
	write_byte(g, 0)

	// Terminator
	write_byte(g, 0)
}

write_byte :: proc(g: ^GifWriter, byte: u8) {
	write_bytes(g, []u8{byte})
}

write_bytes :: proc(g: ^GifWriter, bytes: []u8) {
	switch &dst in g.meta.dst {
	case [dynamic]u8:
		append(&dst, ..bytes)
	case os.Handle:
		// TODO(2025-03-31, Max Bolotin): Actually handle writing directly to file
		fmt.println("TODO: Not implemented")
		os.exit(1)
	}
}

write_image :: proc(g: ^GifWriter, width: uint, height: uint, img: []u8) -> WriteImageError {
	tmp: []u8
	i, j: uint

	fmt.println("Writing ", len(img), "bytes to data block")

	indexed_img, err := make([]u8, width * height)
	// defer delete(indexed_img)

	if err != nil {
		fmt.println("Error: Couldn't allocate indexed image buffer in write_image():", err)
		return err
	}

	for i = 0; i < height; i += 1 {
		for j = 0; j < width; j += 1 {
			red, green, blue: u8
			index: uint

			index = (i * width) + j
			red = img[(3 * index) + 0]
			green = img[(3 * index) + 1]
			blue = img[(3 * index) + 2]
			indexed_img[(i * width) + j] = calc_color(g, red, green, blue)
		}
	}
	fmt.println("Indexed image size:", len(indexed_img), "bytes")
	fmt.println("Initial code size (bit width):", g.code_size)
	compress_err, compr := lzw.compress_gif(g.code_size, indexed_img)
	if compress_err != nil {
		fmt.println("Error when compressing GIF:", compress_err)
		return compress_err
	}
	defer delete(compr)

	fmt.println("Compressed size: ", len(compr))
	fmt.println("Post-compression code size (bit width):", g.code_size)

	tmp = compr[:]

	write_byte(g, g.code_size)

	for len(tmp) > 255 {
		write_byte(g, 255)
		write_bytes(g, tmp[:255])
		tmp = tmp[255:]
	}

	if len(tmp) > 0 {
		write_byte(g, u8(len(tmp)))
		write_bytes(g, tmp)
	}

	write_byte(g, 0)

	return nil
}

write_u16 :: proc(dst: []u8, val: u16) {
	dst[0] = u8(val & 0xff)
	dst[1] = u8((val >> 8) & 0xff)
}

writer_create :: proc(
	code_size: u8,
	palette: []u8,
	width: uint,
	height: uint,
) -> (
	runtime.Allocator_Error,
	GifWriter,
) {
	g := GifWriter{}
	g.width = width
	g.height = height
	if palette != nil {
		g.code_size = code_size
		g.n_colors = 1 << g.code_size
		g.palette = palette
	} else {
		g.code_size = 8
		g.n_colors = 256
		g.palette = DEFAULT_PALETTE
	}
	err: runtime.Allocator_Error
	g.meta.dst, err = make([dynamic]u8, 0, g.width * g.height)

	if err != nil {
		fmt.println("Error: Could not allocate destination buffer for gif writer:", err)
		return err, GifWriter{}
	}

	header(&g)
	logical_screen(&g)
	netscape_loop(&g)

	return nil, g
}

writer_end :: proc(g: ^GifWriter, out_len: ^uint) -> []u8 {
	if g == nil {
		return nil
	}
	write_byte(g, u8(GifTag.TagTrailer))

	#partial switch dst in &g.meta.dst {
	case [dynamic]u8:
		out_len^ = len(dst)
		return dst[:]
	}

	return nil
}

writer_push :: proc(
	g: ^GifWriter,
	opts: ^GifOpts,
	left: uint,
	top: uint,
	width: uint,
	height: uint,
	img: []byte,
) {
	if g == nil {
		return
	}

	if opts != nil {
		graphic_control(g, opts)
	}

	image_descriptor(g, left, top, width, height)

	write_image(g, width, height, img)

	return
}
