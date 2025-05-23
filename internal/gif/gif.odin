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

GifSourceType :: enum {
	GifFile,
	GifBuffer,
}

GifTag :: enum (u8) {
	TagGraphicExtension    = 0x21,
	TagGraphicControlLabel = 0xf9,
	TagCommentLabel        = 0xfe,
	TagApplicationLabel    = 0xff,
	TagPlainTextLabel      = 0x01,
	TagImageDescriptor     = 0x2c,
	TagTrailer             = 0x3b,
}

GifWriterMetaDst :: union {
	[dynamic]u8,
	os.Handle,
}

WriteImageError :: union #shared_nil {
	runtime.Allocator_Error,
	lzw.CompressError,
}

GifGraphicControlFlags :: bit_field u8 {
	transparent_color: bool | 1,
	user_input:        bool | 1,
	disposal_method:   bool | 3,
	reserved:          bool | 3,
}

GifOpts :: struct {
	delay:       uint,
	flags:       GifGraphicControlFlags,
	trans_index: u8,
}

GifWriter :: struct {
	meta:      GifWriterMeta,
	width:     uint,
	height:    uint,
	n_colors:  uint,
	code_size: u8,
	palette:   []u8,
}

GifWriterMeta :: struct {
	dst: GifWriterMetaDst,
}

ImageDescriptorFlags :: bit_field u8 {
	local_color_table_size: u8   | 3,
	reserved:               u8   | 2,
	sort:                   bool | 1,
	interlace:              bool | 1,
	local_color_table:      bool | 1,
}
RgbPixel :: struct {
	is_transparent: b8,
	b:              u8,
	g:              u8,
	r:              u8,
}

calc_color :: proc(r: u8, g: u8, b: u8, n_colors: uint, palette: []u8) -> u8 {
	i: uint
	result: struct {
		min:   u32,
		index: u8,
	}

	result.min = ~u32(0)
	result.index = 0

	for i = 0; i < n_colors; i += 1 {
		pr, pg, pb: u8
		index, delta: uint

		index = 3 * i
		pr = palette[index + 0]
		pg = palette[index + 1]
		pb = palette[index + 2]
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
	header[1] = u8(opts.flags)

	write_u16(header[2:], u16(opts.delay))

	if opts.flags.transparent_color {
		header[4] = opts.trans_index
	} else {
		header[4] = 0
	}

	write_bytes(g, header[:])

	// Terminator
	write_byte(g, 0)
}

header :: proc(g: ^GifWriter) {
	GIF_HEADER_SIZE :: #config(GIF_HEADER_SIZE, 6)

	version := []u8{'G', 'I', 'F', '8', '9', 'a'}

	write_bytes(g, version)
}

image_descriptor :: proc(
	g: ^GifWriter,
	left: uint,
	top: uint,
	width: uint,
	height: uint,
	flags: ImageDescriptorFlags,
) {
	IMAGE_DESCRIPTOR_SIZE :: 9

	header: [IMAGE_DESCRIPTOR_SIZE]u8

	write_byte(g, u8(GifTag.TagImageDescriptor))
	write_u16(header[0:2], u16(left))
	write_u16(header[2:4], u16(top))
	write_u16(header[4:6], u16(width))
	write_u16(header[6:8], u16(height))

	// Flags
	header[8] = u8(flags)
	fmt.printfln("Writing image descriptor flags: %b", u8(flags))

	write_bytes(g, header[:])
}

logical_screen :: proc(g: ^GifWriter) {
	LOGICAL_SCREEN_DESCRIPTOR_SIZE :: 7
	GLOBAL_COLOR_TABLE_FLAG :: 0x80
	GLOBAL_COLOR_TABLE_SIZE :: 0x07

	lsd: [LOGICAL_SCREEN_DESCRIPTOR_SIZE]u8

	write_u16(lsd[:2], u16(g.width))
	write_u16(lsd[2:4], u16(g.height))

	// Set global palette if defined
	if g.palette != nil {
		lsd[4] = GLOBAL_COLOR_TABLE_FLAG
		lsd[4] |= u8(g.code_size - 1)
	}

	// Bg color index
	lsd[5] = 0
	// Aspect
	lsd[6] = 0

	// Write the logical screen descriptor header
	write_bytes(g, lsd[:])

	// Actually write the color table
	if g.palette != nil {
		write_bytes(g, g.palette)
	}
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

write_image :: proc(
	g: ^GifWriter,
	width: uint,
	height: uint,
	img: []RgbPixel,
	lct_code_size: u8,
	lct_palette: []u8,
	enable_transparency: bool,
	transparency_index: u8,
) -> WriteImageError {
	tmp: []u8
	i, j: uint

	fmt.println("Writing ", len(img) * 3, "bytes to data block")

	indexed_img, err := make([]u8, width * height)
	// defer delete(indexed_img)

	if err != nil {
		fmt.println("Error: Couldn't allocate indexed image buffer in write_image():", err)
		return err
	}

	palette: []u8
	code_size: u8
	if lct_palette == nil {
		palette = g.palette
		code_size = g.code_size
	} else {
		palette = lct_palette
		code_size = lct_code_size
	}
	n_colors: uint = (1 << lct_code_size)

	for i = 0; i < height; i += 1 {
		for j = 0; j < width; j += 1 {
			index := (i * width) + j
			col := img[index]

			if enable_transparency && col.is_transparent {
				indexed_img[index] = transparency_index
			} else {
				indexed_img[index] = calc_color(col.r, col.g, col.b, n_colors, palette)
			}
		}
	}

	fmt.println("Indexed image size:", len(indexed_img), "bytes")
	compress_err, compr := lzw.compress_gif(code_size, indexed_img)
	if compress_err != nil {
		fmt.println("Error when compressing GIF:", compress_err)
		return compress_err
	}
	defer delete(compr)

	fmt.println("Compressed size: ", len(compr))

	tmp = compr[:]

	write_byte(g, code_size)

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
		g.palette = nil
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
	img: []RgbPixel,
	lct_code_size: u8,
	lct_palette: []u8,
) {
	if g == nil {
		return
	}

	if opts != nil {
		graphic_control(g, opts)
	}

	flags := ImageDescriptorFlags{}
	if lct_palette != nil {
		flags.local_color_table = true
		flags.local_color_table_size = lct_code_size - 1
	}

	image_descriptor(g, left, top, width, height, flags)

	// Write local color table if available
	if lct_palette != nil {
		write_bytes(g, lct_palette)
	}

	fmt.println(
		"Writing image with transparency=",
		opts.flags.transparent_color,
		"with index",
		opts.trans_index,
	)

	write_image(
		g,
		width,
		height,
		img,
		lct_code_size,
		lct_palette,
		opts.flags.transparent_color,
		opts.trans_index,
	)

	return
}
