package main
// TODO(2025-03-23, Max Bolotin): Post-shader upscaling via render texture
// TODO(2025-03-23, Max Bolotin): Better way of handling brightness/blending with bg color. How can we make background color of palette be present in the voronoi tesselations without muddying the look of the palette?
// TODO(2025-03-23, Max Bolotin): Better way of selecting which monitor to display on (if it's a wallpaper it should probably be displayed on all monitors - one process per monitor?)
// TODO(2025-03-26, Max Bolotin): Port another shader to dynawall (monterrey2?). Set up some themes in home manager to use it instead of voronoi2.
// TODO(2025-03-26, Max Bolotin): Look into setting up an OpenGL context via EGL, and rendering onto a framebuffer
// TODO(2025-03-26, Max Bolotin): Export as PNG
// TODO(2025-03-26, Max Bolotin): Export as HEIC
// TODO(2025-03-26, Max Bolotin): Export as GIF (boomerang effect? Maybe we always want to run the time through a sine function before passing it to the shader, so we can make sure the wallpaper loops smoothly even with a limited time frame)

import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:log"
import "core:math"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sys/posix"
import "core:time"
import "internal/gif"
import "internal/lzw"
import gl "vendor:OpenGL"
import egl "vendor:egl"
import "vendor:glfw"
import "vendor:stb/image"

GL_MAJOR_VERSION: c.int : 3
CONFIG_FILE_TEMPLATE :: #load("./dynawall.conf.tmpl")
FRAME_LIMIT :: 24
GL_MINOR_VERSION :: 3
NANOSECONDS_PER_SECOND :: 1000 * 1000 * 1000
PROGRAMNAME :: "Dynawall"
SHADER_HOT_RELOADING :: #config(SHADER_HOT_RELOADING, false)

config: Config
config_file: string
running: b32 = true

ColorBox :: struct {
	start: int,
	end:   int,
}

Config :: struct {
	palette: Palette,
	shader:  ShaderType,
}

ExportContext :: struct {
	image:             ImageContext,
	time:              TimeContext,
	export_image_type: ExportImageType,
	window:            glfw.WindowHandle,
	out_path:          string,
}

GLContext :: struct {
	vao:                    u32,
	vbo:                    u32,
	ebo:                    u32,
	program:                u32,
	shader_type:            ShaderType,
	hot_reload_shader_path: string,
	hot_reload_shader_ts:   i64,
}

HsvColor :: struct {
	h: f32,
	s: f32,
	v: f32,
}

IOWriteContext :: struct {
	offset: int,
	writer: io.Writer,
}

ImageContext :: struct {
	width:  i32,
	height: i32,
}

Options :: struct {
	command:          string `args:"pos=0,required" usage:"command to run - either 'serve' or 'export'"`,
	config:           string `usage:"path to config file - default ~/.config/dynawall.conf"`,
	export_out:       string `args:"n=export-out" usage:"file to export image to when used with export command, must be either PNG och HEIC format, default is 'wallpaper.heic'`,
	export_width:     i32 `usage:"width of the image being exported, by default set to the resolution width of the primary monitor"`,
	export_height:    i32 `usage:"height of the image being exported, by default set to the resolution height of the primary monitor"`,
	export_localtime: string `args:"n=export-local-time" usage:"overrides system local time when exporting a non-dynamic image (PNG)"`,
	seconds_start:    f64 `args:"n=seconds-start" usage:"sets the initial number of seconds elapsed for the shader, or when exporting, the amount of seconds elapsed at the moment of snapshoting, defaults to 0"`,
	seconds_end:      f64 `args:"n=seconds-end" usage:"sets the max amount of seconds the shader runs before resetting the time value to 0. If no value is set, the timer never resets."`,
	boomerang:        bool `usage:"activates boomerang mode if --seconds-end is set. Makes the shader plot against a bezier triangle function of the time value, so that time periodically and smoothly returns to 0"`,
}

Palette :: struct {
	accents_rgb:  [10]RgbColor,
	accents_hsv:  [10]HsvColor,
	accents_size: u32,
	bg_rgb:       RgbColor,
	bg_hsv:       HsvColor,
	is_dark:      bool,
}

RgbColor :: struct {
	r: f32,
	g: f32,
	b: f32,
}

ServeContext :: struct {
	image:  ImageContext,
	time:   TimeContext,
	window: glfw.WindowHandle,
	frame:  i32,
}

TimeContext :: struct {
	boomerang:              bool,
	local_time:             f32,
	delta:                  f64,
	seconds_elapsed:        f64,
	limit_start, limit_end: f64,
}

URgbColor :: struct {
	r: u8,
	g: u8,
	b: u8,
}

UniformLocations :: struct {
	time_location:         i32,
	time_delta_location:   i32,
	resolution_location:   i32,
	is_dark_location:      i32,
	bg_rgb_location:       i32,
	bg_hsv_location:       i32,
	accents_rgb_location:  i32,
	accents_hsv_location:  i32,
	accents_size_location: i32,
	mouse_location:        i32,
}

ExportImageType :: enum {
	GIF,
	PNG,
	HEIC,
}

ShaderType :: enum {
	Helloworld    = 0,
	Voronoi2      = 1,
	Monterrey2    = 2,
	Voronoi2NoBuf = 3,
}


alloc_draw_to_byte_buffer :: proc(
	img_ctx: ^ImageContext,
	time_ctx: ^TimeContext,
	gl_ctx: ^GLContext,
	ul: ^UniformLocations,
	format: u32,
	channel_count: i32,
) -> []u8 {
	out_size := img_ctx.width * img_ctx.height * channel_count
	out := make([]byte, out_size)
	draw(img_ctx, gl_ctx, time_ctx, ul)
	gl.ReadPixels(0, 0, img_ctx.width, img_ctx.height, format, gl.UNSIGNED_BYTE, &out[0])
	return out
}

// Takes a value between 0 and 1 and interpolates it along a bezier curve
bezier_blend :: proc {
	bezier_blend_f32,
	bezier_blend_f64,
}

bezier_blend_f32 :: proc(t: f32) -> f32 {
	assert(t >= 0)
	assert(t <= 1)
	return t * t * (3 - 2 * t)
}

bezier_blend_f64 :: proc(t: f64) -> f64 {
	assert(t >= 0)
	assert(t <= 1)
	return t * t * (3 - 2 * t)
}

build_uniform_palette :: proc() -> []u8 {
	palette := make([]u8, 256 * 3)
	i := 0
	for r in 0 ..< 8 {
		for g in 0 ..< 8 {
			for b in 0 ..< 4 {
				palette[i + 0] = u8(r * 255 / 7)
				palette[i + 1] = u8(g * 255 / 7)
				palette[i + 2] = u8(b * 255 / 3)
				i += 3
			}
		}
	}
	return palette
}

calc_time_uniform :: proc(time_ctx: ^TimeContext) -> f64 {
	t := time_ctx.seconds_elapsed
	period := time_ctx.limit_end - time_ctx.limit_start

	if time_ctx.limit_end != 0 {
		if time_ctx.boomerang {
			t = math.abs(triangle_wave(1, period * 4, t))
			t_abs_offset := time_ctx.limit_start + time_ctx.seconds_elapsed
			if t_abs_offset >= time_ctx.limit_end / 2 {
				t = bezier_blend(t)
			}
			t *= period
		} else {
			t = math.mod(t, period)
		}
	}

	t += time_ctx.limit_start

	return t
}

create_time_ctx :: proc(opts: ^Options) -> (bool, TimeContext) {
	time_ctx := TimeContext{}
	time_ctx.limit_start = opts.seconds_start
	time_ctx.limit_end = opts.seconds_end
	time_ctx.boomerang = opts.boomerang
	time_ctx.delta = 0
	time_ctx.seconds_elapsed = 0
	time_ctx.local_time = 0

	if time_ctx.limit_end == 0 && time_ctx.boomerang {
		fmt.println("Error: Can't use boomerang mode if --seconds-end is not set or set to 0")
		return false, TimeContext{}
	}

	return true, time_ctx
}

cursor_position_callback :: proc "c" (window: glfw.WindowHandle, x_pos: f64, y_pos: f64) {
	// mouse_x = x_pos
	// mouse_y = y_pos
}

draw :: proc(
	image: ^ImageContext,
	gl_ctx: ^GLContext,
	time_ctx: ^TimeContext,
	ul: ^UniformLocations,
) {
	gl.Viewport(0, 0, image.width, image.height)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(gl_ctx.program)

	set_uniform_values(ul, time_ctx, image)

	gl.BindVertexArray(gl_ctx.vao)

	if is_buffer_required(gl_ctx.shader_type) {
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	} else {
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
	}

}

export :: proc(opts: ^Options) -> bool {
	ctx := ExportContext{}

	ctx_time_ok: bool
	ctx_time_ok, ctx.time = create_time_ctx(opts)
	if !ctx_time_ok {
		return false
	}

	if opts.export_out != "" {
		ctx.out_path = opts.export_out
	} else {
		ctx.out_path = "wallpaper.png"
	}

	out_rev := strings.reverse(ctx.out_path)
	part_rev, _ := strings.split_iterator(&out_rev, ".")
	part := strings.to_lower(strings.reverse(part_rev))

	switch (part) {
	case "png":
		ctx.export_image_type = .PNG
	case "gif":
		ctx.export_image_type = .GIF
	case "heic":
		ctx.export_image_type = .HEIC
	case:
		fmt.println("Error: Unknown output file format:", part)
		os.exit(1)
	}


	if (glfw.Init() != true) {
		fmt.println("Failed to initialize GLFW")
		return false
	}
	defer glfw.Terminate()

	primary_monitor := glfw.GetPrimaryMonitor()
	primary_monitor_vm := glfw.GetVideoMode(primary_monitor)

	if opts.export_width != 0 {
		ctx.image.width = opts.export_width
	} else {
		ctx.image.width = primary_monitor_vm.width
	}

	if opts.export_height != 0 {
		ctx.image.height = opts.export_height
	} else {
		ctx.image.height = primary_monitor_vm.height
	}

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.FOCUSED, glfw.FALSE)

	if (ODIN_OS == .Darwin) {
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
	}

	ctx.window = glfw.CreateWindow(ctx.image.width, ctx.image.height, PROGRAMNAME, nil, nil)
	if ctx.window == nil {
		fmt.println("Unable to create window")
		return false
	}
	defer glfw.DestroyWindow(ctx.window)

	glfw.HideWindow(ctx.window)
	glfw.MakeContextCurrent(ctx.window)
	glfw.SwapInterval(1)

	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl_ok, gl_ctx := gl_setup()
	if !gl_ok {
		return false
	}
	defer gl_teardown(&gl_ctx)

	ul := get_uniform_locations(gl_ctx.program)

	fbo: u32 = 0
	gl.GenFramebuffers(1, &fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

	rendered_texture: u32
	gl.GenTextures(1, &rendered_texture)

	gl.BindTexture(gl.TEXTURE_2D, rendered_texture)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGB,
		ctx.image.width,
		ctx.image.height,
		0,
		gl.RGB,
		gl.UNSIGNED_BYTE,
		nil,
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)

	gl.FramebufferTexture(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, rendered_texture, 0)

	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		fmt.println("Error setting up framebuffer")
		return false
	}

	switch (ctx.export_image_type) {
	case .GIF:
		return export_gif(&ctx, &gl_ctx, &ul)
	case .PNG:
		return export_png(&ctx, &gl_ctx, &ul)
	case .HEIC:
		return export_heic(&ctx, &gl_ctx, &ul)
	}

	return true
}

export_gif :: proc(ctx: ^ExportContext, gl_ctx: ^GLContext, ul: ^UniformLocations) -> bool {
	EXPORT_FORMAT :: gl.RGB
	EXPORT_FORMAT_CHANNEL_SIZE :: 3
	PER_FRAME_DELAY_CENTISECONDS: f64 : 6
	PER_FRAME_DELAY_SECONDS: f64 : PER_FRAME_DELAY_CENTISECONDS / 100

	if ctx.time.limit_end == 0 {
		fmt.println("Can't export GIF without a known end time, please specifiy --seconds-end")
		return false
	}

	// Create writer without global color table
	err, writer := gif.writer_create(8, nil, uint(ctx.image.width), uint(ctx.image.height))
	if err != nil {
		fmt.println("Error initializing GIF writer, exiting")
		return false
	}

	period := ctx.time.limit_end - ctx.time.limit_start
	if ctx.time.boomerang {
		period *= 2
	}

	ctx.time.seconds_elapsed = 0

	total_frames := int(math.ceil(period / PER_FRAME_DELAY_SECONDS))

	last_bytes: []u8
	defer {
		if last_bytes != nil {
			delete(last_bytes)
		}
	}

	for frame_number in 1 ..= total_frames {
		fmt.println(
			"Generating frame ",
			frame_number,
			"/",
			total_frames,
			" @ time ",
			ctx.time.seconds_elapsed,
		)

		glfw.MakeContextCurrent(ctx.window)

		transparent_color_flag := last_bytes != nil

		gif_opts := gif.GifOpts {
			delay = uint(PER_FRAME_DELAY_CENTISECONDS),
			trans_index = 0,
			flags = {transparent_color = transparent_color_flag},
		}

		image_bytes := alloc_draw_to_byte_buffer(
			&ctx.image,
			&ctx.time,
			gl_ctx,
			ul,
			EXPORT_FORMAT,
			EXPORT_FORMAT_CHANNEL_SIZE,
		)

		vert_flip_image(image_bytes, int(ctx.image.width))

		pixels := get_pixels(last_bytes, image_bytes, ctx.image.width, ctx.image.height)
		defer delete(pixels)

		if last_bytes != nil {
			delete(last_bytes)
		}
		last_bytes = image_bytes

		// Local color table
		palette := median_cut_quantize(pixels, 256)
		defer delete(palette)

		gif.writer_push(
			&writer,
			&gif_opts,
			0,
			0,
			uint(ctx.image.width),
			uint(ctx.image.height),
			pixels,
			8,
			palette,
		)

		log.info("Writer push successful")

		glfw.SwapBuffers(ctx.window)

		ctx.time.delta = PER_FRAME_DELAY_SECONDS
		ctx.time.seconds_elapsed = min(period, ctx.time.seconds_elapsed + PER_FRAME_DELAY_SECONDS)
	}

	out_len: uint = 0

	fmt.println("Closing GIF writer and outputing result to buffer")
	out := gif.writer_end(&writer, &out_len)
	defer delete(out)

	write_err := os.write_entire_file_or_err(ctx.out_path, out)

	if write_err != nil {
		fmt.println("Error writing GIF file:", write_err)
		return false
	}

	fmt.println("Wrote file to disk OK")

	return true
}

export_heic :: proc(ctx: ^ExportContext, gl_ctx: ^GLContext, ul: ^UniformLocations) -> bool {
	fmt.println("ERROR: Not implemented: HEIC export")
	return false
}

export_png :: proc(ctx: ^ExportContext, gl_ctx: ^GLContext, ul: ^UniformLocations) -> bool {
	EXPORT_FORMAT :: gl.RGB
	EXPORT_FORMAT_CHANNEL_SIZE :: 3

	out := alloc_draw_to_byte_buffer(
		&ctx.image,
		&ctx.time,
		gl_ctx,
		ul,
		EXPORT_FORMAT,
		EXPORT_FORMAT_CHANNEL_SIZE,
	)
	defer delete(out)

	ok: bool
	handle: os.Handle
	write_ctx: IOWriteContext

	ok, handle = open_rw_writer_create_if_notexists(ctx.out_path)
	if !ok {
		return false
	}
	defer os.close(handle)

	ok, write_ctx = io_write_context_from_handle(handle)

	image.flip_vertically_on_write(true)

	write_result := image.write_png_to_func(
		write_image_data,
		&write_ctx,
		ctx.image.width,
		ctx.image.height,
		EXPORT_FORMAT_CHANNEL_SIZE,
		&out[0],
		EXPORT_FORMAT_CHANNEL_SIZE * ctx.image.width,
	)

	if write_result != 1 {
		fmt.println("Warning: Got a non-successful write result from write_png_to_func")
	}

	return true
}

get_frag_shader_embedded :: proc(shader_type: ShaderType) -> string {
	bytes: []byte
	switch (shader_type) {
	case .Monterrey2:
		bytes = #load("./shaders/monterrey2.frag")
	case .Voronoi2NoBuf:
		fallthrough
	case .Voronoi2:
		bytes = #load("./shaders/voronoi2.frag")
	case .Helloworld:
		bytes = #load("./shaders/helloworld.frag")
	}
	return transmute(string)bytes
}

get_frag_shader_path :: proc(shader_type: ShaderType) -> string {
	path: string
	switch (shader_type) {
	case .Monterrey2:
		path = "./shaders/monterrey2.frag"
	case .Voronoi2NoBuf:
		path = "./shaders/voronoi2.frag"
	case .Voronoi2:
		path = "./shaders/voronoi2.frag"
	case .Helloworld:
		path = "./shaders/helloworld.frag"
	}
	return path
}

get_pixels :: proc(prev: []u8, next: []u8, width: i32, height: i32) -> []gif.RgbPixel {
	out := make([]gif.RgbPixel, width * height * 3)

	for i in 0 ..< height {
		for j in 0 ..< width {
			index := (i * width) + j
			byte_offset := 3 * index

			if prev == nil {
				out[index] = gif.RgbPixel {
					is_transparent = false,
					r              = next[byte_offset],
					g              = next[byte_offset + 1],
					b              = next[byte_offset + 2],
				}

				continue
			}

			if prev[byte_offset] == next[byte_offset] &&
			   prev[byte_offset + 1] == next[byte_offset + 1] &&
			   prev[byte_offset + 2] == next[byte_offset + 2] {
				out[index] = gif.RgbPixel {
					is_transparent = true,
					r              = 0,
					g              = 0,
					b              = 0,
				}
				continue
			}

			out[index] = gif.RgbPixel {
				is_transparent = false,
				r              = next[byte_offset],
				g              = next[byte_offset + 1],
				b              = next[byte_offset + 2],
			}
		}
	}

	return out
}

get_shader_prog :: proc(shader_type: ShaderType) -> (bool, u32) {
	program: u32
	ok: bool

	if SHADER_HOT_RELOADING {
		vs_path := get_vert_shader_path(shader_type)
		fs_path := get_frag_shader_path(shader_type)
		program, ok = gl.load_shaders_file(vs_path, fs_path)
	} else {
		vs_src := get_vert_shader_embedded(shader_type)
		fs_src := get_frag_shader_embedded(shader_type)
		program, ok = gl.load_shaders_source(vs_src, fs_src)
	}

	if !ok {
		fmt.println("Error loading shader")
		return false, 0
	}

	return true, program
}

get_uniform_location :: proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, strings.clone_to_cstring(str))
}

get_uniform_locations :: proc(program: u32) -> UniformLocations {
	ul := UniformLocations{}
	ul.time_location = get_uniform_location(program, "iTime\x00")
	ul.time_delta_location = get_uniform_location(program, "iTimeDelta\x00")
	ul.resolution_location = get_uniform_location(program, "iResolution\x00")
	ul.is_dark_location = get_uniform_location(program, "iPaletteIsDark\x00")
	ul.bg_rgb_location = get_uniform_location(program, "iPaletteBgRgb\x00")
	ul.bg_hsv_location = get_uniform_location(program, "iPaletteBgHsv\x00")
	ul.accents_rgb_location = get_uniform_location(program, "iPaletteAccentsRgb\x00")
	ul.accents_hsv_location = get_uniform_location(program, "iPaletteAccentsHsv\x00")
	ul.accents_size_location = get_uniform_location(program, "iPaletteAccentsSize\x00")
	ul.mouse_location = get_uniform_location(program, "iMouse\x00")
	return ul
}

get_vert_shader_embedded :: proc(shader_type: ShaderType) -> string {
	bytes: []byte
	switch (shader_type) {
	case .Monterrey2:
		fallthrough
	case .Voronoi2:
		fallthrough
	case .Helloworld:
		bytes = #load("./vertex_shader.vert")
	case .Voronoi2NoBuf:
		bytes = #load("./vertex_nobuf.vert")
	}
	return transmute(string)bytes
}

get_vert_shader_path :: proc(shader_type: ShaderType) -> string {
	path: string
	switch (shader_type) {
	case .Monterrey2:
		fallthrough
	case .Voronoi2:
		fallthrough
	case .Helloworld:
		path = "./vertex_shader.vert"
	case .Voronoi2NoBuf:
		path = "./vertex_nobuf.vert"
	}
	return path
}

gl_setup :: proc() -> (bool, GLContext) {
	gl_ctx := GLContext{}

	program_ok, program := get_shader_prog(config.shader)
	if !program_ok {
		return false, GLContext{}
	}

	if SHADER_HOT_RELOADING {
		gl_ctx.hot_reload_shader_path = get_frag_shader_path(config.shader)
		info, err := os.stat(gl_ctx.hot_reload_shader_path)

		if err != nil {
			fmt.println("Error checking hot reload path, hot reloading will not work")
		} else {
			gl_ctx.hot_reload_shader_ts = info.modification_time._nsec
		}
	}

	gl_ctx.shader_type = config.shader
	gl_ctx.program = program

	gl.GenVertexArrays(1, &gl_ctx.vao)
	gl.BindVertexArray(gl_ctx.vao)

	if (is_buffer_required(gl_ctx.shader_type)) {
		vertices := []f32{1.0, 1.0, 0.0, 1.0, -1.0, 0.0, -1.0, -1.0, 0.0, -1.0, 1.0, 0.0}
		indices := []u32{0, 1, 3, 1, 2, 3}

		gl.GenBuffers(1, &gl_ctx.vbo)
		gl.GenBuffers(1, &gl_ctx.ebo)

		gl.BindBuffer(gl.ARRAY_BUFFER, gl_ctx.vbo)
		gl.BufferData(gl.ARRAY_BUFFER, 12 * size_of(f32), &vertices[0], gl.STATIC_DRAW)

		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl_ctx.ebo)
		gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, 6 * size_of(u32), &indices[0], gl.STATIC_DRAW)

		gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
		gl.EnableVertexAttribArray(0)

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	}

	gl.ClearColor(1.0, 1.0, 1.0, 1.0)

	return true, gl_ctx
}

gl_teardown :: proc(gl_ctx: ^GLContext) {
	gl.DeleteVertexArrays(1, &gl_ctx.vao)
	gl.DeleteBuffers(1, &gl_ctx.vbo)
	gl.DeleteBuffers(1, &gl_ctx.ebo)
	gl.DeleteProgram(gl_ctx.program)
}

hex_to_col :: proc(hex: string) -> (bool, RgbColor) {
	color_bytes: [3]byte
	last_byteval: byte = 0
	hex_lower := strings.to_lower(hex)

	for rune, idx in hex_lower {
		if (idx == 0) {
			if (rune != '#') {
				return false, RgbColor{}
			}
			continue
		}
		byteval: byte
		if (rune >= 0x30 && rune <= 0x39) {
			byteval = byte(rune) - 0x30
		} else if (rune >= 0x61 && rune <= 0x66) {
			byteval = 10 + byte(rune) - 0x61
		} else {
			return false, RgbColor{}
		}
		if (idx % 2 != 0) {
			last_byteval = byteval * 16
		} else {
			c_idx: uint = uint(math.floor(f32(idx - 1) / 2))
			color_bytes[c_idx] = last_byteval + byteval
		}
	}

	color := RgbColor {
		r = f32(color_bytes[0]) / 255,
		g = f32(color_bytes[1]) / 255,
		b = f32(color_bytes[2]) / 255,
	}

	return true, color
}

io_write_context_from_handle :: proc(handle: os.Handle) -> (bool, IOWriteContext) {
	stream := os.stream_from_handle(handle)
	writer, ok := io.to_writer(stream)

	if !ok {
		fmt.println("Unable to open write interface")
		return false, IOWriteContext{}
	}

	write_ctx: IOWriteContext = {
		writer = writer,
		offset = 0,
	}

	return true, write_ctx
}
is_buffer_required :: proc(type: ShaderType) -> bool {
	switch (type) {
	case .Voronoi2NoBuf:
		return false
	case .Helloworld:
		fallthrough
	case .Voronoi2:
		fallthrough
	case:
		fallthrough
	case .Monterrey2:
		return true
	}
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if key == glfw.KEY_ESCAPE {
		running = false
	}
}

load_config :: proc() -> bool {
	config_file_path := replace_envs_in_str(config_file)
	exists := os.exists(config_file_path)

	if !exists && !os.write_entire_file(config_file_path, CONFIG_FILE_TEMPLATE) {
		fmt.println("Couldn't create dynawall config, access denied")
		return false
	}

	data, ok := os.read_entire_file(config_file_path)
	if !ok {
		fmt.println("Couldn't read dynawall config, unknown error")
		return false
	}

	ok, config = parse_config(data)

	if !ok {
		return false
	}

	return true
}

main :: proc() {
	args := os.args

	opts: Options
	flags.parse_or_exit(&opts, args, .Unix)

	config_file = opts.config
	if config_file == "" {
		config_file = "$HOME/.config/dynawall.conf"
	}
	fmt.printfln("config file: %s", config_file)

	if opts.seconds_start > 0 && opts.seconds_end > 0 && opts.seconds_start >= opts.seconds_end {
		fmt.printfln(
			"Error: When using --seconds-start with --seconds-end, --seconds-end must be bigger than --seconds-start",
		)
		os.exit(1)
	}

	if opts.boomerang && opts.seconds_end == 0 {
		fmt.println("Error: --seconds-end must be defined when using --boomerang")
	}

	ok := load_config()
	if !ok {
		fmt.println("Error loading initial config, falling back to application defaults")
		ok, config = parse_config(CONFIG_FILE_TEMPLATE)
	}
	if !ok {
		fmt.println("Error parsing system wide config, something is seriously wrong")
		fmt.println("Panicing")
		os.exit(1)
	}

	fmt.println(opts)

	command_ok: bool

	switch opts.command {
	case "serve":
		posix.signal(posix.Signal.SIGUSR1, signal_reload_config)
		serve(&opts)
	case "export":
		command_ok = export(&opts)
	case:
		fmt.println("Unknown command:", opts.command)
		command_ok = false
	}

	if !command_ok {
		os.exit(1)
	}

	fmt.println("Successfully exited")
	os.exit(0)
}

median_cut_quantize :: proc(pixels: []gif.RgbPixel, max_colors: int) -> []u8 {
	num_pixels := len(pixels)
	if num_pixels == 0 {
		return nil
	}

	colors := make([]URgbColor, num_pixels)
	defer delete(colors)
	for i in 0 ..< num_pixels {
		if pixels[i].is_transparent {
			continue
		}

		colors[i] = URgbColor {
			r = pixels[i].r,
			g = pixels[i].g,
			b = pixels[i].b,
		}
	}

	boxes := make([dynamic]ColorBox, 0, max_colors)
	defer delete(boxes)

	append(&boxes, ColorBox{start = 0, end = num_pixels})

	sort_component :: proc(arr: []URgbColor, start, end: int, channel: string) {
		s := arr[start:end]
		switch channel {
		case "r":
			slice.sort_by(s, proc(a, b: URgbColor) -> bool {return a.r < b.r})
		case "g":
			slice.sort_by(s, proc(a, b: URgbColor) -> bool {return a.g < b.g})
		case "b":
			slice.sort_by(s, proc(a, b: URgbColor) -> bool {return a.b < b.b})
		}
	}

	for len(boxes) < max_colors {
		// Find the box with the most pixels
		longest := 0
		for i in 1 ..< len(boxes) {
			if (boxes[i].end - boxes[i].start) > (boxes[longest].end - boxes[longest].start) {
				longest = i
			}
		}

		box := boxes[longest]
		count := box.end - box.start
		if count <= 1 {
			break
		}

		// Find channel with greatest range
		rmin, rmax: u8 = 255, 0
		gmin, gmax: u8 = 255, 0
		bmin, bmax: u8 = 255, 0
		for i in box.start ..< box.end {
			c := colors[i]
			if c.r < rmin {rmin = c.r}
			if c.r > rmax {rmax = c.r}
			if c.g < gmin {gmin = c.g}
			if c.g > gmax {gmax = c.g}
			if c.b < bmin {bmin = c.b}
			if c.b > bmax {bmax = c.b}
		}
		dr := rmax - rmin
		dg := gmax - gmin
		db := bmax - bmin

		channel := "r"
		if dg > dr && dg >= db {
			channel = "g"
		} else if db > dr && db >= dg {
			channel = "b"
		}

		// Sort and split at median
		sort_component(colors, box.start, box.end, channel)
		mid := (box.start + box.end) / 2

		// Replace box with two halves
		boxes[longest] = ColorBox {
			start = box.start,
			end   = mid,
		}
		append(&boxes, ColorBox{start = mid, end = box.end})
	}

	palette := make([]u8, len(boxes) * 3)

	for box, i in boxes {
		r_total, g_total, b_total := 0, 0, 0
		count := box.end - box.start
		for j in box.start ..< box.end {
			c := colors[j]
			r_total += int(c.r)
			g_total += int(c.g)
			b_total += int(c.b)
		}
		if count == 0 {count = 1} 	// prevent div by 0
		palette[i * 3 + 0] = u8(r_total / count)
		palette[i * 3 + 1] = u8(g_total / count)
		palette[i * 3 + 2] = u8(b_total / count)
	}

	return palette
}

open_rw_writer_create_if_notexists :: proc(path: string) -> (bool, os.Handle) {
	file_exists := os.exists(path)
	path_c := strings.clone_to_cstring(path)
	handle, err := os.open(path, os.O_WRONLY | os.O_CREATE)


	if !file_exists {
		err := posix.chmod(path_c, {.IRUSR, .IWUSR, .IRGRP, .IROTH})
		if err != nil {
			fmt.println("Error setting file permissions for exported file:", err)
			return false, 0x00
		}
	}

	if err != nil {
		fmt.println("Error opening file for writing:", path, err)
		return false, 0x00
	}

	return true, handle
}

parse_config :: proc(data: []byte) -> (bool, Config) {
	config := Config{}

	ConfigJsonData :: struct {
		palette: struct {
			accents: [dynamic]string,
			bg:      string,
		},
		shader:  string,
	}

	json_config: ConfigJsonData
	err := json.unmarshal(data, &json_config)

	if err != nil {
		fmt.println("Error parsing config JSON")
		return false, config
	}

	ok, bg_color := hex_to_col(json_config.palette.bg)

	if !ok {
		fmt.println("Error parsing background color", json_config.palette.bg)
		return false, config
	}

	config.palette.bg_rgb = bg_color
	config.palette.bg_hsv = rgb_to_hsv(bg_color)
	config.palette.is_dark = config.palette.bg_hsv.v < 0.5

	config.palette.accents_size = u32(len(json_config.palette.accents))

	if config.palette.accents_size > 10 {
		fmt.println(
			"Warning: Config file includes too many accent colors, truncating to the first 10 only",
		)
		config.palette.accents_size = 10
	}

	for accent, i in json_config.palette.accents {
		if i >= 10 {
			break
		}
		ok, color := hex_to_col(accent)
		if !ok {
			fmt.printfln(
				"Unexpected config data: Couldn't convert hex %s to an rgb color value",
				accent,
			)
			return false, config
		}
		config.palette.accents_rgb[i] = color
		config.palette.accents_hsv[i] = rgb_to_hsv(color)
	}

	config.shader = parse_shader(json_config.shader)

	return true, config
}

parse_shader :: proc(shader_str: string) -> ShaderType {
	switch (shader_str) {
	case "voronoi2":
		return .Voronoi2
	case "voronoi2nobuf":
		return .Voronoi2NoBuf
	case "monterrey2":
		return .Monterrey2
	case:
		fmt.println("Warning: No shader selected in config, defaulting to helloworld")
		fallthrough
	case "default":
		fallthrough
	case "helloworld":
		return .Helloworld
	}
}

proper_mod :: proc {
	proper_mod_f32,
	proper_mod_f64,
}

proper_mod_f32 :: proc(dividend: f32, divisor: f32) -> f32 {
	return math.mod(math.mod(dividend, divisor) + divisor, divisor)
}

proper_mod_f64 :: proc(dividend: f64, divisor: f64) -> f64 {
	return math.mod(math.mod(dividend, divisor) + divisor, divisor)
}

replace_envs_in_str :: proc(str: string) -> string {
	output, _ := strings.replace_all(str, "$HOME", os.get_env("HOME"))
	return output
}

rgb_to_hsv :: proc(rgb_color: RgbColor) -> HsvColor {
	max := rgb_color.r
	if (rgb_color.g > max) {
		max = rgb_color.g
	}
	if (rgb_color.b > max) {
		max = rgb_color.b
	}

	min := rgb_color.r
	if (rgb_color.g < min) {
		min = rgb_color.g
	}
	if (rgb_color.b < min) {
		min = rgb_color.b
	}

	delta := max - min

	s := delta / max

	r := (max - rgb_color.r) / delta
	g := (max - rgb_color.g) / delta
	b := (max - rgb_color.b) / delta

	h: f32

	if (max == min) {
		h = 0
	} else if (max == rgb_color.r) {
		h = b - g
	} else if (max == rgb_color.g) {
		h = 2 + r - b
	} else {
		h = 4 + g - r
	}

	h = proper_mod_f32((h / 6), 1)

	v := max

	hsv := HsvColor {
		h = h,
		s = s,
		v = v,
	}

	return hsv
}

serve :: proc(opts: ^Options) -> bool {
	if (glfw.Init() != true) {
		fmt.println("Failed to initialize GLFW")
		return false
	}
	defer glfw.Terminate()

	monitors := glfw.GetMonitors()
	contexts: [dynamic]ServeContext

	for monitor, i in monitors[1:] {
		ok, ctx := serve_setup_context(monitor, opts)
		if !ok {
			fmt.printfln("Error while initializing monitor context %d, panicing", i)
			return false
		}
		append(&contexts, ctx)
	}

	defer {
		for &ctx in contexts {
			serve_close_context(&ctx)
		}
	}

	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl_ok, gl_ctx := gl_setup()
	if !gl_ok {
		return false
	}
	defer gl_teardown(&gl_ctx)

	ul := get_uniform_locations(gl_ctx.program)

	for running != false {
		for &ctx, i in contexts {
			serve_update(&ctx, &gl_ctx, &ul)
		}
	}

	return true
}

serve_close_context :: proc(ctx: ^ServeContext) {
	glfw.DestroyWindow(ctx.window)
}

serve_setup_context :: proc(monitor: glfw.MonitorHandle, opts: ^Options) -> (bool, ServeContext) {
	ctx := ServeContext{}

	time_ctx_ok: bool

	time_ctx_ok, ctx.time = create_time_ctx(opts)
	if !time_ctx_ok {
		return false, ServeContext{}
	}

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.DECORATED, glfw.FALSE)
	glfw.WindowHint(glfw.FOCUSED, glfw.FALSE)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.FOCUS_ON_SHOW, glfw.FALSE)

	if (ODIN_OS == .Darwin) {
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
	} else {
		glfw.WindowHintString(glfw.WAYLAND_APP_ID, PROGRAMNAME)
	}

	video_mode := glfw.GetVideoMode(monitor)
	fs_monitor := ODIN_OS == .Darwin ? nil : monitor
	ctx.window = glfw.CreateWindow(
		video_mode.width,
		video_mode.height,
		PROGRAMNAME,
		fs_monitor,
		nil,
	)
	if ctx.window == nil {
		fmt.println("Unable to create window")
		return false, ServeContext{}
	}

	glfw.SetCursorPosCallback(ctx.window, cursor_position_callback)
	glfw.SetKeyCallback(ctx.window, key_callback)
	glfw.SetFramebufferSizeCallback(ctx.window, size_callback)

	glfw.MakeContextCurrent(ctx.window)
	glfw.SwapInterval(1)

	ctx.frame = 0

	return true, ctx
}

serve_update :: proc(ctx: ^ServeContext, gl_ctx: ^GLContext, ul: ^UniformLocations) {
	if (glfw.WindowShouldClose(ctx.window)) {
		running = false
		return
	}

	frame_time_start := time.tick_now()

	if ctx.frame == 0 {
		if gl_ctx.shader_type != config.shader {
			fmt.println("Shader type changed in config, loading new shader")

			ok, program := get_shader_prog(config.shader)

			if !ok {
				fmt.println("Error loading shader")
				os.exit(1)
			}

			gl.DeleteProgram(gl_ctx.program)

			gl_ctx.program = program
			gl_ctx.shader_type = config.shader

			if SHADER_HOT_RELOADING {
				gl_ctx.hot_reload_shader_path = get_frag_shader_path(config.shader)
			}

			ul^ = get_uniform_locations(gl_ctx.program)
		}

		if SHADER_HOT_RELOADING {
			info, err := os.stat(gl_ctx.hot_reload_shader_path)

			if err != nil {
				fmt.println("Error checking hot reload path, hot reloading will not work")
			} else if info.modification_time._nsec > gl_ctx.hot_reload_shader_ts {
				fmt.println("Shader has changed, reloading")

				ok, program := get_shader_prog(gl_ctx.shader_type)
				if !ok {
					fmt.println("Error reloading shader")
				} else {
					gl_ctx.program = program
				}

				gl_ctx.hot_reload_shader_ts = info.modification_time._nsec
			}
		}
	}

	glfw.MakeContextCurrent(ctx.window)

	ctx.image.width, ctx.image.height = glfw.GetFramebufferSize(ctx.window)
	ctx.time.seconds_elapsed = glfw.GetTime()

	draw(&ctx.image, gl_ctx, &ctx.time, ul)

	glfw.SwapBuffers(ctx.window)

	glfw.PollEvents()

	frame_time_end := time.tick_now()
	delta_ns := time.tick_diff(frame_time_start, frame_time_end)

	if (FRAME_LIMIT > 0) {
		if (delta_ns < NANOSECONDS_PER_SECOND) {
			time.sleep((NANOSECONDS_PER_SECOND / FRAME_LIMIT) - delta_ns)
			ctx.time.delta = 1 / FRAME_LIMIT
		} else {
			ctx.time.delta = f64(delta_ns / NANOSECONDS_PER_SECOND)
		}
	} else {
		ctx.time.delta = f64(delta_ns / NANOSECONDS_PER_SECOND)
	}
	ctx.frame = (ctx.frame + 1) % FRAME_LIMIT
}

set_uniform_values :: proc(ul: ^UniformLocations, time_ctx: ^TimeContext, image: ^ImageContext) {
	t := calc_time_uniform(time_ctx)
	gl.Uniform1f(ul.time_location, f32(t))
	gl.Uniform1f(ul.time_delta_location, f32(time_ctx.delta))
	gl.Uniform3f(ul.resolution_location, f32(image.width), f32(image.height), 0)

	if ul.is_dark_location != -1 {
		gl.Uniform1ui(ul.is_dark_location, u32(config.palette.is_dark))
	}

	if ul.bg_rgb_location != -1 {
		gl.Uniform3f(
			ul.bg_rgb_location,
			config.palette.bg_rgb.r,
			config.palette.bg_rgb.g,
			config.palette.bg_rgb.b,
		)
	}

	if ul.bg_hsv_location != -1 {
		gl.Uniform3f(
			ul.bg_hsv_location,
			config.palette.bg_hsv.h,
			config.palette.bg_hsv.s,
			config.palette.bg_hsv.v,
		)
	}

	if ul.accents_size_location != -1 {
		gl.Uniform1ui(ul.accents_size_location, config.palette.accents_size)
	}

	if ul.accents_rgb_location != -1 || ul.accents_hsv_location != -1 {
		for i: u32 = 0; i < config.palette.accents_size; i += 1 {
			if (ul.accents_rgb_location != -1) {
				color := config.palette.accents_rgb[i]
				loc: i32 = ul.accents_rgb_location + i32(i)
				gl.Uniform3f(loc, color.r, color.g, color.b)
			}
			if (ul.accents_hsv_location != -1) {
				color := config.palette.accents_hsv[i]
				loc: i32 = ul.accents_hsv_location + i32(i)
				gl.Uniform3f(loc, color.h, color.s, color.v)
			}
		}
	}
}

signal_reload_config :: proc "c" (_: posix.Signal) {
	context = runtime.default_context()
	old_shader := config.shader

	fmt.println("Reloading config")
	_ = load_config()
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

triangle_wave :: proc {
	triangle_wave_f32,
	triangle_wave_f64,
}

triangle_wave_f32 :: proc(amplitude: f32, period: f32, x: f32) -> f32 {
	return(
		(4 * amplitude / period) * math.abs(proper_mod(x - period / 4, period) - period / 2) -
		amplitude \
	)
}
triangle_wave_f64 :: proc(amplitude: f64, period: f64, x: f64) -> f64 {
	return(
		(4 * amplitude / period) * math.abs(proper_mod(x - period / 4, period) - period / 2) -
		amplitude \
	)
}

vert_flip_image :: proc(img_data: []u8, width: int) {
	height := int(math.floor(f32(len(img_data) / width / 3)))
	for bottom_row in 0 ..< (height / 2) {
		top_row := height - bottom_row - 1
		if top_row == bottom_row {
			break
		}
		for j in 0 ..< width {
			bottom_cell := (bottom_row * width * 3) + (j * 3)
			top_cell := (top_row * width * 3) + (j * 3)
			for c in 0 ..< 3 {
				bottom_color := bottom_cell + c
				top_color := top_cell + c
				t := img_data[top_color]
				img_data[top_color] = img_data[bottom_color]
				img_data[bottom_color] = t
			}
		}
	}
}

write_image_data :: proc "c" (ctx: rawptr, data: rawptr, size: c.int) {
	context = runtime.default_context()
	write_ctx := cast(^IOWriteContext)ctx
	bytes := slice.bytes_from_ptr(data, int(size))
	_, err := io.write(write_ctx.writer, bytes, &write_ctx.offset)
	if err != nil {
		fmt.println("Write Error:", err)
	}
}
