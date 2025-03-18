// GLFW and OpenGL example with very verbose comments and links to documentation for learning
// By Soren Saket

// semi-colons ; are not requied in odin
// 

// Every Odin script belongs to a package 
// Define the package with the package [packageName] statement
// The main package name is reserved for the program entry point package
// You cannot have two different packages in the same directory
// If you want to create another package create a new directory and name the package the same as the directory
// You can then import the package with the import keyword
// https://odin-lang.org/docs/overview/#packages
package main

// Import statement
// https://odin-lang.org/docs/overview/#packages

// Odin by default has two library collections. Core and Vendor
// Core contains the default library all implemented in the Odin language
// Vendor contains bindings for common useful packages aimed at game and software development
// https://odin-lang.org/docs/overview/#import-statement

// fmt contains formatted I/O procedures.
// https://pkg.odin-lang.org/core/fmt/
import "core:fmt"
// C interoperation compatibility
import "core:c"
import "core:os"
import "core:strings"

// Here we import OpenGL and rename it to gl for short
import gl "vendor:OpenGL"
// We use GLFW for cross platform window creation and input handling
import "vendor:glfw"


// Odin has type type inference
// variableName := value
// variableName : type = value
// You can set constants with ::

PROGRAMNAME :: "Dynawall"

// GL_VERSION define the version of OpenGL to use. Here we use 4.6 which is the newest version
// You might need to lower this to 3.3 depending on how old your graphics card is.
// Constant with explicit type for example
GL_MAJOR_VERSION: c.int : 3
// Constant with type inference
GL_MINOR_VERSION :: 3

// Our own boolean storing if the application is running
// We use b32 for allignment and easy compatibility with the glfw.WindowShouldClose procedure
// See https://odin-lang.org/docs/overview/#basic-types for more information on the types in Odin
running: b32 = true
window: glfw.WindowHandle
resx, resy: c.int

// The main function is the entry point for the application
// In Odin functions/methods are more precisely named procedures
// procedureName :: proc() -> returnType
// https://odin-lang.org/docs/overview/#procedures
main :: proc() {
	// Initialize glfw
	// GLFW_TRUE if successful, or GLFW_FALSE if an error occurred.
	// GLFW_TRUE = 1
	// GLFW_FALSE = 0
	// https://www.glfw.org/docs/latest/group__init.html#ga317aac130a235ab08c6db0834907d85e
	if (glfw.Init() != true) {
		// Print Line
		fmt.println("Failed to initialize GLFW")
		// Return early
		return
	}
	defer glfw.Terminate()

	// Set Window Hints
	// https://www.glfw.org/docs/3.3/window_guide.html#window_hints
	// https://www.glfw.org/docs/3.3/group__window.html#ga7d9c8c62384b1e2821c4dc48952d2033
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	if (ODIN_OS == .Darwin) {
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
		fmt.println("this is a mac")
	} else {
		glfw.WindowHintString(glfw.WAYLAND_APP_ID, PROGRAMNAME)
	}

	// fmt.println(gl.GetString(gl.GL_Enum.VERSION))
	// the defer keyword makes the procedure run when the calling procedure exits scope
	// Deferes are executed in reverse order. So the window will get destoryed first
	// They can also just be called manually later instead without defer. This way of doing it ensures are terminated.
	// https://odin-lang.org/docs/overview/#defer-statement
	// https://www.glfw.org/docs/3.1/group__init.html#gaaae48c0a18607ea4a4ba951d939f0901
	defer glfw.Terminate()

	monitor := glfw.GetPrimaryMonitor()
	video_mode := glfw.GetVideoMode(monitor)

	resx, resy = video_mode.width, video_mode.height
	// Create the window
	// Return WindowHandle rawPtr
	// https://www.glfw.org/docs/3.3/group__window.html#ga3555a418df92ad53f917597fe2f64aeb
	window = glfw.CreateWindow(resx, resy, PROGRAMNAME, monitor, nil)
	// https://www.glfw.org/docs/latest/group__window.html#gacdf43e51376051d2c091662e9fe3d7b2
	defer glfw.DestroyWindow(window)

	// If the window pointer is invalid
	if window == nil {
		fmt.println("Unable to create window")
		return
	}

	//
	// https://www.glfw.org/docs/3.3/group__context.html#ga1c04dc242268f827290fe40aa1c91157
	glfw.MakeContextCurrent(window)

	// Enable vsync
	// https://www.glfw.org/docs/3.3/group__context.html#ga6d4e0cdf151b5e579bd67f13202994ed
	glfw.SwapInterval(1)

	// This function sets the key callback of the specified window, which is called when a key is pressed, repeated or released.
	// https://www.glfw.org/docs/3.3/group__input.html#ga1caf18159767e761185e49a3be019f8d
	glfw.SetKeyCallback(window, key_callback)

	// This function sets the framebuffer resize callback of the specified window, which is called when the framebuffer of the specified window is resized.
	// https://www.glfw.org/docs/3.3/group__window.html#gab3fb7c3366577daef18c0023e2a8591f
	glfw.SetFramebufferSizeCallback(window, size_callback)

	// Set OpenGL Context bindings using the helper function
	// See Odin Vendor source for specifc implementation details
	// https://github.com/odin-lang/Odin/tree/master/vendor/OpenGL
	// https://www.glfw.org/docs/3.3/group__context.html#ga35f1837e6f666781842483937612f163

	// casting the c.int to int
	// This is needed because the GL_MAJOR_VERSION has an explicit type of c.int
	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address)

	// load shaders
	program, shader_success := gl.load_shaders("vertex_shader.vert", "./shaders/helloworld.frag")
	if (shader_success == false) {
		fmt.println("Error loading shader")
		return
	}

	defer gl.DeleteProgram(program)

	// setup vao
	vao: u32
	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)

	gl.BindVertexArray(vao)

	vertex_data := [8]f32{-1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0}

	vbo: u32
	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertex_data), &vertex_data[0], gl.STATIC_DRAW)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, 0)

	gl.ClearColor(1.0, 1.0, 1.0, 1.0)
	// There is only one kind of loop in Odin called for
	// https://odin-lang.org/docs/overview/#for-statement
	for (!glfw.WindowShouldClose(window) && running) {
		// Process waiting events in queue
		// https://www.glfw.org/docs/3.3/group__window.html#ga37bd57223967b4211d60ca1a0bf3c832
		glfw.PollEvents()

		gl.Clear(gl.COLOR_BUFFER_BIT)

		// setup shader program and uniforms
		gl.UseProgram(program)
		gl.Uniform1f(get_uniform_location(program, "iGlobalTime\x00"), f32(glfw.GetTime()))
		gl.Uniform3f(
			get_uniform_location(program, "iResolution\x00"),
			f32(resx),
			f32(resy),
			f32(0.0),
		)

		// accents_start := get_uniform_location(program, "iPaletteAccents\x00")
		//
		// gl.Uniform3f(accents_start, 1, 0, 0)
		// gl.Uniform3f(accents_start + 1, 0, 1, 0)
		// gl.Uniform3f(accents_start + 2, 0, 0, 1)

		// draw stuff
		gl.BindVertexArray(vao)
		// gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

		glfw.SwapBuffers(window)
	}
}

// Called when glfw keystate changes
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	// Exit program on escape pressed
	if key == glfw.KEY_ESCAPE {
		running = false
	}
}

// Called when glfw window changes size
size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	// Set the OpenGL viewport size
	gl.Viewport(0, 0, width, height)
}

// wrapper to use GetUniformLocation with an Odin string
// NOTE: str has to be zero-terminated, so add a \x00 at the end
get_uniform_location :: proc(program: u32, str: string) -> i32 {
	return gl.GetUniformLocation(program, strings.clone_to_cstring(str))
}
