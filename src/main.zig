const std = @import("std");

const cimgui = @import("cimgui.zig"); // cimgui with builtin GLFW/GL3 backend.
const glfw3 = @import("glfw3.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{
        .safety = true,
        .verbose_log = true,
        .enable_memory_limit = true,
    }){
        .requested_memory_limit = 10 * 4096,
    };
    defer {
        const check = general_purpose_allocator.deinit();
        switch (check) {
            .ok => {},
            .leak => _ = general_purpose_allocator.detectLeaks(),
        }
    }
    const gpa = general_purpose_allocator.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    // GLFW3 window
    if (glfw3.glfwInit() != glfw3.GLFW_TRUE) @panic("glfwInit");
    defer glfw3.glfwTerminate();

    const window_size = cimgui.ImVec2{ .x = 800, .y = 600 };
    const target_frames_per_second = 60.0;

    const window = window: {
        glfw3.glfwWindowHint(glfw3.GLFW_OPENGL_FORWARD_COMPAT, glfw3.GLFW_TRUE);
        glfw3.glfwWindowHint(glfw3.GLFW_OPENGL_PROFILE, glfw3.GLFW_OPENGL_CORE_PROFILE);
        glfw3.glfwWindowHint(glfw3.GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfw3.glfwWindowHint(glfw3.GLFW_CONTEXT_VERSION_MINOR, 2);

        const monitor = null;
        const share = null;
        const window = glfw3.glfwCreateWindow(window_size.x, window_size.y, "client", monitor, share) orelse @panic("glfwCreateWindow");
        errdefer glfw3.glfwDestroyWindow(window);

        glfw3.glfwMakeContextCurrent(window);
        glfw3.glfwSwapInterval(1);
        break :window window;
    };
    defer glfw3.glfwDestroyWindow(window);

    const context = cimgui.igCreateContext(null) orelse @panic("igCreateContext");
    defer cimgui.igDestroyContext(context);
    cimgui.igSetCurrentContext(context);

    // ImGui for GLFW
    if (!cimgui.ImGui_ImplGlfw_InitForOpenGL(@ptrCast(window), true)) @panic("ImGui_ImplGlfw_InitForOpenGL");
    defer cimgui.ImGui_ImplGlfw_Shutdown();

    const glsl_version = "#version 130"; // GL 3.2, GLSL 1.3
    if (!cimgui.ImGui_ImplOpenGL3_Init(glsl_version)) @panic("ImGui_ImplOpenGL3_Init");
    defer cimgui.ImGui_ImplOpenGL3_Shutdown();

    const io = cimgui.igGetIO_Nil();
    var pixels: [*c]u8 = null;
    var width: c_int = 0;
    var height: c_int = 0;
    const bytes_per_pixel: c_int = 0;
    cimgui.ImFontAtlas_GetTexDataAsRGBA32(io.*.Fonts, &pixels, &width, &height, bytes_per_pixel);

    cimgui.igStyleColorsDark(null);

    io.*.DisplaySize = window_size;
    io.*.DeltaTime = 1.0 / target_frames_per_second; // ms
    io.*.ConfigFlags |= cimgui.ImGuiConfigFlags_DockingEnable; // NOTE: currently requires "docking_inter" branch.

    while (glfw3.glfwWindowShouldClose(window) != glfw3.GLFW_TRUE) {
        glfw3.glfwPollEvents();
        cimgui.ImGui_ImplOpenGL3_NewFrame();
        cimgui.ImGui_ImplGlfw_NewFrame();
        cimgui.igNewFrame();

        // cimgui content.
        cimgui.igShowDemoWindow(null);

        // render and swap
        cimgui.igRender();
        glfw3.glfwMakeContextCurrent(window);
        glfw3.glViewport(0, 0, @intFromFloat(io.*.DisplaySize.x), @intFromFloat(io.*.DisplaySize.y));
        glfw3.glClearColor(0, 0, 0, 1);
        glfw3.glClear(glfw3.GL_COLOR_BUFFER_BIT);
        cimgui.ImGui_ImplOpenGL3_RenderDrawData(@ptrCast(cimgui.igGetDrawData()));
        glfw3.glfwSwapBuffers(window);
    }
}
