package main
// TODO(2025-03-23, Max Bolotin): Post-shader upscaling via render texture
// TODO(2025-03-23, Max Bolotin): Better way of handling brightness/blending with bg color. How can we make background color of palette be present in the voronoi tesselations without muddying the look of the palette?
// TODO(2025-03-23, Max Bolotin): Better way of selecting which monitor to display on (if it's a wallpaper it should probably be displayed on all monitors - one process per monitor?)

import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:flags"
import "core:fmt"
import "core:io"
import "core:math"
import "core:os"
import "core:strings"
import "core:sys/posix"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:glfw"

RgbColor :: struct {
	r: f32,
	g: f32,
	b: f32,
}

HsvColor :: struct {
	h: f32,
	s: f32,
	v: f32,
}

Palette :: struct {
	accents_rgb:  [10]RgbColor,
	accents_hsv:  [10]HsvColor,
	accents_size: u32,
	bg_rgb:       RgbColor,
	bg_hsv:       HsvColor,
	is_dark:      bool,
}

Config :: struct {
	palette: Palette,
}

PROGRAMNAME :: "Dynawall"
FRAME_LIMIT :: 24
NANOSECONDS_PER_SECOND :: 1000 * 1000 * 1000
GL_MAJOR_VERSION: c.int : 3
GL_MINOR_VERSION :: 3
CONFIG_FILE_TEMPLATE :: #load("./dynawall.conf.tmpl")

running: b32 = true
config: Config
config_file: string

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

TimeContext :: struct {
	local_time:  f32,
	start, end:  time.Tick,
	delta_ns:    time.Duration,
	delta:       f64,
	glfw_time:   f64,
	frame_time:  f64,
	time_cyclic: f64,
}

ImageContext :: struct {
	width:  i32,
	height: i32,
}

ServeContext :: struct {
	image:  ImageContext,
	time:   TimeContext,
	window: glfw.WindowHandle,
	frame:  i32,
}

serve_close_context :: proc(ctx: ^ServeContext) {
	glfw.DestroyWindow(ctx.window)
}

serve_setup_context :: proc(monitor: glfw.MonitorHandle) -> (bool, ServeContext) {
	ctx := ServeContext{}
	ctx.time.start = time.tick_now()

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.DECORATED, glfw.FALSE)
	glfw.WindowHint(glfw.FOCUSED, glfw.FALSE)

	if (ODIN_OS == .Darwin) {
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
	} else {
		glfw.WindowHintString(glfw.WAYLAND_APP_ID, PROGRAMNAME)
	}

	video_mode := glfw.GetVideoMode(monitor)
	ctx.window = glfw.CreateWindow(video_mode.width, video_mode.height, PROGRAMNAME, nil, nil)
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

serve_update :: proc(ctx: ^ServeContext, program: u32, ul: UniformLocations, vao: u32) {
	if (glfw.WindowShouldClose(ctx.window)) {
		running = false
		return
	}

	glfw.MakeContextCurrent(ctx.window)

	ctx.time.start = time.tick_now()

	ctx.image.width, ctx.image.height = glfw.GetFramebufferSize(ctx.window)

	gl.Viewport(0, 0, ctx.image.width, ctx.image.height)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(program)

	ctx.time.glfw_time = glfw.GetTime()

	set_uniform_values(ul, ctx.time, ctx.image)

	gl.BindVertexArray(vao)
	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

	glfw.SwapBuffers(ctx.window)

	glfw.PollEvents()

	ctx.time.end = time.tick_now()

	ctx.time.delta_ns = time.tick_diff(ctx.time.start, ctx.time.end)

	if (FRAME_LIMIT > 0) {
		if (ctx.time.delta_ns < NANOSECONDS_PER_SECOND) {
			time.sleep((NANOSECONDS_PER_SECOND / FRAME_LIMIT) - ctx.time.delta_ns)
			ctx.time.delta = 1 / FRAME_LIMIT
		} else {
			ctx.time.delta = f64(ctx.time.delta_ns / NANOSECONDS_PER_SECOND)
		}
	} else {
		ctx.time.delta = f64(ctx.time.delta_ns / NANOSECONDS_PER_SECOND)
	}
	ctx.frame = (ctx.frame + 1) % FRAME_LIMIT
}

export :: proc(args: []string) {
	ExportOptions :: struct {
		out:             string `args:"pos=0,required" usage:"filename of exported file, must be of formats PNG or HEIC"`,
		seconds_elapsed: f64 `usage:"floating point number representing seconds elapsed since start of shader"`,
		// clock:           string `usage:"ISO timestamp representing current time of the local system, defaults to current time"`,
	}
	opts: ExportOptions

	fmt.println(args)

	flags.parse_or_exit(&opts, args, .Unix)

	fmt.println("export options", opts)

	time_ctx := TimeContext{}
	time_ctx.glfw_time = opts.seconds_elapsed
}

serve :: proc(args: []string) {
	if (glfw.Init() != true) {
		fmt.println("Failed to initialize GLFW")
		return
	}

	defer glfw.Terminate()

	monitors := glfw.GetMonitors()
	contexts: [dynamic]ServeContext

	for monitor, i in monitors {
		ok, ctx := serve_setup_context(monitor)
		if !ok {
			fmt.printfln("Error while initializing monitor context %d, panicing", i)
			return
		}
		append(&contexts, ctx)
	}

	defer {
		for &ctx in contexts {
			serve_close_context(&ctx)
		}
	}

	gl_ok, gl_ctx := gl_setup()
	if !gl_ok {
		return
	}
	defer gl_teardown(&gl_ctx)

	ul := get_uniform_locations(gl_ctx.program)

	for running != false {
		for &ctx, i in contexts {
			serve_update(&ctx, gl_ctx.program, ul, gl_ctx.vao)
		}
	}
}

main :: proc() {
	RootOptions :: struct {
		command:      string `args:"pos=0,required" usage:"command to run - either 'serve' or 'export'"`,
		command_args: [dynamic]string `args:"variadic,hidden"`,
		config:       string `usage:"path to config file - default ~/.config/dynawall.conf"`,
	}

	ServeOptions :: struct {}

	args := os.args

	root_options: RootOptions
	flags.parse_or_exit(&root_options, args, .Unix)

	config_file = root_options.config
	if config_file == "" {
		config_file = "$HOME/.config/dynawall.conf"
	}
	fmt.printfln("config file: %s", config_file)

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

	fmt.println(root_options)

	switch root_options.command {
	case "serve":
		posix.signal(posix.Signal.SIGUSR1, signal_reload_config)
		serve(root_options.command_args[:])
		break
	case "export":
		export(root_options.command_args[:])
		break
	case:
		fmt.println("Unknown command:", root_options.command)
		os.exit(1)
	}
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if key == glfw.KEY_ESCAPE {
		running = false
	}
}

size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
}

get_uniform_location :: proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, strings.clone_to_cstring(str))
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

cursor_position_callback :: proc "c" (window: glfw.WindowHandle, x_pos: f64, y_pos: f64) {
	// mouse_x = x_pos
	// mouse_y = y_pos
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

	h = proper_mod((h / 6), 1)

	v := max

	hsv := HsvColor {
		h = h,
		s = s,
		v = v,
	}

	return hsv
}

proper_mod :: proc(dividend: f32, divisor: f32) -> f32 {
	return math.mod_f32(math.mod_f32(dividend, divisor) + divisor, divisor)
}

parse_config :: proc(data: []byte) -> (bool, Config) {
	config := Config{}

	parsed, err := json.parse(data)

	if err != .None {
		fmt.println("Couldn't parse config JSON")
		return false, config
	}

	root: json.Object

	#partial switch v in parsed {
	case json.Object:
		root = v
	case:
		fmt.println("Unexpected config data: Expected root entity to be an object")
		return false, config
	}

	palette_root: json.Object

	#partial switch v in root["palette"] {
	case json.Object:
		palette_root = v
	case:
		fmt.println("Unexpected config data: Expected <<palette> to contain an object")
		return false, config
	}

	#partial switch v in palette_root["bg"] {
	case json.String:
		ok, color := hex_to_col(v)
		if !ok {
			fmt.printfln(
				"Unexpected config data: Couldn't convert hex %s to an rgb color value",
				v,
			)
			return false, config
		}
		config.palette.bg_rgb = color
		config.palette.bg_hsv = rgb_to_hsv(color)
		config.palette.is_dark = config.palette.bg_hsv.v < 0.5
	}

	accents_data: json.Array

	#partial switch v in palette_root["accents"] {
	case json.Array:
		accents_data = v
		config.palette.accents_size = min(u32(len(v)), 10)
	case:
		fmt.println("Unexpected config data: Expected <<accents>> to contain an array")
		return false, config
	}

	for accent, i in accents_data {
		if i >= 10 {
			break
		}
		#partial switch v in accent {
		case json.String:
			ok, color := hex_to_col(v)
			if !ok {
				fmt.printfln(
					"Unexpected config data: Couldn't convert hex %s to an rgb color value",
					v,
				)
				return false, config
			}
			config.palette.accents_rgb[i] = color
			config.palette.accents_hsv[i] = rgb_to_hsv(color)
		case:
			fmt.println(
				"Unexpected config data: Expected all items in <<accents>> array to be strings",
			)
			return false, config
		}
	}

	return true, config
}

signal_reload_config :: proc "c" (_: posix.Signal) {
	context = runtime.default_context()
	fmt.println("Reloading config")
	_ = load_config()
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

replace_envs_in_str :: proc(str: string) -> string {
	output, _ := strings.replace_all(str, "$HOME", os.get_env("HOME"))
	return output
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

create_shader_program :: proc() -> (bool, u32) {
	program, shader_success := gl.load_shaders("vertex_shader.vert", "./shaders/voronoi2.frag")
	if (shader_success == false) {
		fmt.println("Error loading shader")
		return false, 0
	}

	return true, program
}

set_uniform_values :: proc(ul: UniformLocations, time: TimeContext, image: ImageContext) {
	gl.Uniform1f(ul.time_location, f32(time.glfw_time))
	gl.Uniform1f(ul.time_delta_location, f32(time.delta))
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

GLContext :: struct {
	vao:     u32,
	vbo:     u32,
	ebo:     u32,
	program: u32,
}

gl_teardown :: proc(gl_ctx: ^GLContext) {
	gl.DeleteVertexArrays(1, &gl_ctx.vao)
	gl.DeleteBuffers(1, &gl_ctx.vbo)
	gl.DeleteBuffers(1, &gl_ctx.ebo)
	gl.DeleteProgram(gl_ctx.program)
}

gl_setup :: proc() -> (bool, GLContext) {
	gl_ctx := GLContext{}

	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	program_ok, program := create_shader_program()
	if !program_ok {
		return false, GLContext{}
	}

	gl_ctx.program = program

	vertices := []f32{1.0, 1.0, 0.0, 1.0, -1.0, 0.0, -1.0, -1.0, 0.0, -1.0, 1.0, 0.0}
	indices := []u32{0, 1, 3, 1, 2, 3}

	gl.GenVertexArrays(1, &gl_ctx.vao)
	gl.GenBuffers(1, &gl_ctx.vbo)
	gl.GenBuffers(1, &gl_ctx.ebo)

	gl.BindVertexArray(gl_ctx.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, gl_ctx.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, 12 * size_of(f32), &vertices[0], gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl_ctx.ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, 6 * size_of(u32), &indices[0], gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.ClearColor(1.0, 1.0, 1.0, 1.0)

	return true, gl_ctx
}
