const std = @import("std");

// NOTE: these bindings are created using `make src/glfw3.zig src/cimgui.zig`.
const cimgui = @import("cimgui.zig"); // cimgui with builtin GLFW/GL3 backend.
const glfw3 = @import("glfw3.zig");

pub fn main() !void {
    const start_ts = std.time.nanoTimestamp();

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

    const window_size = cimgui.ImVec2{ .x = 1000, .y = 600 };
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

    var once = false;
    var last_ts = std.time.nanoTimestamp();
    while (glfw3.glfwWindowShouldClose(window) != glfw3.GLFW_TRUE) {
        const now = std.time.nanoTimestamp();
        defer last_ts = now;
        const dt_ns = now - last_ts;
        const dt_s: f32 = @floatCast(@as(f64, @floatFromInt(dt_ns)) / std.time.ns_per_s);

        const elapsed_ns = now - start_ts;
        const elapsed_s: f32 = @floatCast(@as(f64, @floatFromInt(elapsed_ns)) / std.time.ns_per_s);

        glfw3.glfwPollEvents();
        cimgui.ImGui_ImplOpenGL3_NewFrame();
        cimgui.ImGui_ImplGlfw_NewFrame();
        cimgui.igNewFrame();

        // cimgui content.
        cimgui.igShowDemoWindow(null);
        experiment(elapsed_s, dt_s);

        // render and swap
        cimgui.igRender();
        glfw3.glfwMakeContextCurrent(window);
        glfw3.glViewport(0, 0, @intFromFloat(io.*.DisplaySize.x), @intFromFloat(io.*.DisplaySize.y));
        glfw3.glClearColor(0, 0, 0, 1);
        glfw3.glClear(glfw3.GL_COLOR_BUFFER_BIT);
        cimgui.ImGui_ImplOpenGL3_RenderDrawData(@ptrCast(cimgui.igGetDrawData()));
        glfw3.glfwSwapBuffers(window);

        if (!once) {
            once = true;
            std.log.info("time to first frame {d}ms", .{@divFloor(std.time.nanoTimestamp() - start_ts, std.time.ns_per_ms)});
        }
    }
}

var text_buffer = [_]u8{0} ** 4096;

fn experiment(elapsed_s: f32, dt_s: f32) void {
    _ = dt_s;

    // Code view.
    {
        _ = cimgui.igBegin("code", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();
        const draw_list = cimgui.igGetWindowDrawList();

        // _ = cimgui.igText("abc\ndef\n123");

        var cursor_pos: cimgui.ImVec2 = undefined;
        cimgui.igGetCursorScreenPos(&cursor_pos);

        const font_size = cimgui.igGetFontSize();

        const color = cimgui.igGetColorU32_Vec4(.{ .x = 0.3, .y = 0.3, .z = 0.3, .w = 1 });
        const text_color = cimgui.igGetColorU32_Vec4(.{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1 });
        const rounding = 0.0;

        const line_count = 80;
        for (0..line_count) |line| {
            const decorator_offset = 4;
            const offset = @as(f32, @floatFromInt(line)) * font_size + decorator_offset;

            cimgui.ImDrawList_AddRectFilled(
                draw_list,
                .{ .x = cursor_pos.x, .y = cursor_pos.y + offset },
                .{ .x = cursor_pos.x + font_size, .y = cursor_pos.y + offset + font_size - 1 },
                color,
                rounding,
                cimgui.ImDrawFlags_None,
            );

            var line_label_buffer: [20]u8 = undefined;
            const bytes_written = std.fmt.formatIntBuf(&line_label_buffer, line, 10, .lower, .{});
            const text_begin = &line_label_buffer[0];
            const text_end = &line_label_buffer[bytes_written];

            cimgui.ImDrawList_AddText_Vec2(
                draw_list,
                .{ .x = cursor_pos.x, .y = cursor_pos.y + offset },
                text_color,
                text_begin,
                text_end,
            );
        }

        cimgui.igSetCursorScreenPos(.{ .x = cursor_pos.x + font_size, .y = cursor_pos.y });

        const label = "##";
        const callback = null;
        const callback_context = null;
        _ = cimgui.igInputTextMultiline(
            label,
            &text_buffer,
            text_buffer.len,
            .{ .x = 400, .y = line_count * font_size },
            cimgui.ImGuiInputTextFlags_None,
            callback,
            callback_context,
        );
    }

    // Measurement.
    {
        _ = cimgui.igBegin("measurement", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();
        const draw_list = cimgui.igGetWindowDrawList();

        var region_size: cimgui.ImVec2 = undefined;
        cimgui.igGetContentRegionAvail(&region_size);

        var cursor_pos: cimgui.ImVec2 = undefined;
        cimgui.igGetCursorScreenPos(&cursor_pos);

        const speed = 0.2;
        const frequency = 3.0;
        var values = [_]f32{0.0} ** 15;
        for (&values, 0..) |*v, i| {
            const t: f32 = elapsed_s * speed + @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(values.len + 1));
            v.* = std.math.cos(2.0 * std.math.pi * t * frequency);
        }

        const flame_height = 100;
        const plot_region = cimgui.ImVec2{ .x = region_size.x, .y = region_size.y - flame_height };
        const flame_region = cimgui.ImVec2{ .x = region_size.x, .y = flame_height };

        const line_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1 });
        const scatter_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.6, .y = 0.6, .z = 0.6, .w = 1 });
        var last: cimgui.ImVec2 = .{ .x = 0, .y = 0 };
        for (&values, 0..) |*v, i| {
            const x_offset = cursor_pos.x;
            const y_offset = cursor_pos.y;
            const x = @as(f32, @floatFromInt(i)) * plot_region.x / @as(f32, @floatFromInt(values.len));

            const v1 = cimgui.ImVec2{ .x = x + x_offset, .y = ((v.* + 1.0) * 0.5) * plot_region.y + y_offset };

            cimgui.ImDrawList_AddLine(draw_list, v1, last, line_color, 1);
            cimgui.ImDrawList_AddCircleFilled(draw_list, v1, 4, scatter_color, 8);
            last = v1;
        }

        // TODO(pwr): combine measurement values and flame graph in one shared time axis diagram.
        // Classical values on top, flame graph showing dynamic aspects like recursion below and call stack below.
        // Flame graph.
        {
            cimgui.igSetCursorPos(.{ .x = 0, .y = plot_region.y });
            _ = cimgui.igBeginChild_Str("##", flame_region, cimgui.ImGuiChildFlags_None, cimgui.ImGuiWindowFlags_NoDecoration);
            defer cimgui.igEndChild();
            const draw_list_flame = cimgui.igGetWindowDrawList();
            cimgui.igGetCursorScreenPos(&cursor_pos);

            const background_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.9, .y = 0.9, .z = 0.9, .w = 1 });
            cimgui.ImDrawList_AddRectFilled(
                draw_list_flame,
                .{ .x = cursor_pos.x, .y = cursor_pos.y },
                .{ .x = cursor_pos.x + 100, .y = cursor_pos.y + 50 },
                background_color,
                0,
                cimgui.ImDrawFlags_None,
            );

            // _ = cimgui.igButton("test123", .{ .x = cursor_pos.x, .y = cursor_pos.y });
        }
    }

    // Measurement configuration.
    {
        // const Variable = struct {
        //     name: []const u8,
        // };

        // const variables =

        _ = cimgui.igBegin("measurement configuration", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();

        // TODO(pwr):
    }

    // Calibration configuration.
    {
        // const Variable = struct {
        //     name: []const u8,
        // };

        // const variables =

        _ = cimgui.igBegin("calibration", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();

        // TODO(pwr):
    }
}
