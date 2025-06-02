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

    const window_size = cimgui.ImVec2{ .x = 1200, .y = 800 };
    const target_frames_per_second = 60.0;

    const window = window: {
        glfw3.glfwWindowHint(glfw3.GLFW_OPENGL_FORWARD_COMPAT, glfw3.GLFW_TRUE);
        glfw3.glfwWindowHint(glfw3.GLFW_OPENGL_PROFILE, glfw3.GLFW_OPENGL_CORE_PROFILE);
        glfw3.glfwWindowHint(glfw3.GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfw3.glfwWindowHint(glfw3.GLFW_CONTEXT_VERSION_MINOR, 2);

        const monitor = null;
        const share = null;
        const window = glfw3.glfwCreateWindow(window_size.x, window_size.y, "", monitor, share) orelse @panic("glfwCreateWindow");
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

    cimgui.igStyleColorsClassic(null);

    io.*.DisplaySize = window_size;
    io.*.DeltaTime = 1.0 / target_frames_per_second; // ms
    io.*.ConfigFlags |= cimgui.ImGuiConfigFlags_DockingEnable; // NOTE: currently requires "docking_inter" branch.

    experimentInit();

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

var recursive_color: cimgui.ImU32 = undefined;
var main_event_color: cimgui.ImU32 = undefined;
var text_buffer = [_]u8{0} ** 4096;

fn experimentInit() void {
    // TODO(pwr): load JSON dump of measurements from DWARF.
    // => don't implement protocol in this PoC.

    @memset(&text_buffer, 0);
    const example_code = @embedFile("test.c");
    @memcpy(text_buffer[0..example_code.len], example_code);

    recursive_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.5, .y = 0.5, .z = 1.0, .w = 1 });
    main_event_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.5, .y = 1.0, .z = 0.5, .w = 1 });
}

fn experiment(elapsed_s: f32, dt_s: f32) void {
    _ = elapsed_s;
    _ = dt_s;

    const font_size = cimgui.igGetFontSize();
    const grid_x = 25;
    const grid_y = 5;

    // Code view.
    {
        _ = cimgui.igBegin("code", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();
        const draw_list = cimgui.igGetWindowDrawList();

        // _ = cimgui.igText("abc\ndef\n123");

        var cursor_pos: cimgui.ImVec2 = undefined;
        cimgui.igGetCursorScreenPos(&cursor_pos);

        const color = cimgui.igGetColorU32_Vec4(.{ .x = 0.3, .y = 0.3, .z = 0.3, .w = 1 });
        const text_color = cimgui.igGetColorU32_Vec4(.{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1 });
        const rounding = 0.0;

        const line_count = 60;
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

        drawGrid(draw_list, grid_x, grid_y, region_size, cursor_pos, font_size);

        const width = region_size.x / @as(f32, @floatFromInt(grid_x));
        const height = region_size.y / @as(f32, @floatFromInt(grid_y));

        {
            const line_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1 });
            const scatter_color = recursive_color;

            const values = [_]cimgui.ImVec2{
                .{ .x = 0 * width, .y = region_size.y - 0 * height },
                .{ .x = 6 * width, .y = region_size.y - 0 * height },
                .{ .x = 6.5 * width, .y = region_size.y - 1 * height },
                .{ .x = 7 * width, .y = region_size.y - 2 * height },
                .{ .x = 16 * width, .y = region_size.y - 0 * height },
                .{ .x = 16.5 * width, .y = region_size.y - 1 * height },
                .{ .x = 17 * width, .y = region_size.y - 2 * height },
                .{ .x = 25 * width, .y = region_size.y - 0 * height },
            };

            var last = values[0];
            for (&values) |*value| {
                const v1 = cimgui.ImVec2{ .x = value.x + cursor_pos.x, .y = value.y + cursor_pos.y };
                defer last = v1;

                cimgui.ImDrawList_AddLine(draw_list, v1, last, line_color, 1);

                const radius = 6;
                const segments = 4;
                cimgui.ImDrawList_AddNgonFilled(draw_list, v1, radius, scatter_color, segments);
            }
        }

        {
            const line_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1 });
            const scatter_color = main_event_color;

            const values = [_]cimgui.ImVec2{
                .{ .x = 0 * width, .y = region_size.y - 2 * height },
                .{ .x = 3 * width, .y = region_size.y - 2 * height },
                .{ .x = 13 * width, .y = region_size.y - 3 * height },
                .{ .x = 25 * width, .y = region_size.y - 3 * height },
            };

            var last = values[0];
            for (&values) |*value| {
                const v1 = cimgui.ImVec2{ .x = value.x + cursor_pos.x, .y = value.y + cursor_pos.y };
                defer last = v1;

                cimgui.ImDrawList_AddLine(draw_list, v1, last, line_color, 1);

                const radius = 6;
                const segments = 4;
                cimgui.ImDrawList_AddNgonFilled(draw_list, v1, radius, scatter_color, segments);
            }
        }
    }

    // TODO(pwr): combine measurement values and flame graph in one shared time axis diagram.
    // Classical values on top, flame graph showing dynamic aspects like recursion below and call stack below.
    // Flame graph.
    {
        // _ = cimgui.igBeginChild_Str(
        //     "##",
        //     .{ .x = flame_region.Max.x - flame_region.Min.x, .y = flame_region.Max.y - flame_region.Min.y },
        //     cimgui.ImGuiChildFlags_None,
        //     cimgui.ImGuiWindowFlags_NoDecoration,
        // );
        // defer cimgui.igEndChild();
        _ = cimgui.igBegin("flame graph", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();

        const draw_list_flame = cimgui.igGetWindowDrawList();

        var flame_region_size: cimgui.ImVec2 = undefined;
        cimgui.igGetContentRegionAvail(&flame_region_size);

        var flame_cursor_pos: cimgui.ImVec2 = undefined;
        cimgui.igGetCursorScreenPos(&flame_cursor_pos);

        drawGrid(draw_list_flame, grid_x, grid_y, flame_region_size, flame_cursor_pos, font_size);

        const Draw = struct {
            draw_list: *cimgui.ImDrawList,
            base: cimgui.ImVec2,

            fn span(self: @This(), x: f32, y: f32, width: f32, height: f32, comptime format: []const u8, format_args: anytype) void {
                const color = cimgui.igGetColorU32_Vec4(.{ .x = 0.3, .y = 0.3, .z = 0.3, .w = 1 });
                const border_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.9, .y = 0.9, .z = 0.9, .w = 1 });
                const border_size = 1;
                const text_color = border_color;

                cimgui.ImDrawList_AddRectFilled(
                    self.draw_list,
                    .{ .x = self.base.x + x, .y = self.base.y + y },
                    .{ .x = self.base.x + x + width, .y = self.base.y + y + height },
                    border_color,
                    0,
                    cimgui.ImDrawFlags_None,
                );

                cimgui.ImDrawList_AddRectFilled(
                    self.draw_list,
                    .{ .x = self.base.x + x + border_size, .y = self.base.y + y + border_size },
                    .{ .x = self.base.x + x + width - border_size, .y = self.base.y + y + height - border_size },
                    color,
                    0,
                    cimgui.ImDrawFlags_None,
                );

                var label: [80]u8 = undefined;
                const bytes_written = std.fmt.bufPrint(&label, format, format_args) catch @panic("format failed");
                const text_begin = &label[0];
                const text_end = &label[bytes_written.len];
                cimgui.ImDrawList_AddText_Vec2(
                    self.draw_list,
                    .{ .x = self.base.x + x + border_size, .y = self.base.y + y + height * 0.5 },
                    text_color,
                    text_begin,
                    text_end,
                );
            }

            fn event(self: @This(), x: f32, y: f32, color: cimgui.ImU32, comptime format: []const u8, format_args: anytype) void {
                const border_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.9, .y = 0.9, .z = 0.9, .w = 1 });
                const line_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.9, .y = 0.9, .z = 0.9, .w = 1 });
                const border_size = 1;
                const text_color = border_color;

                _ = line_color;

                // const v1 = cimgui.ImVec2{ .x = self.base.x + x, .y = self.base.y };
                // const v2 = cimgui.ImVec2{ .x = self.base.x + x, .y = self.base.y + 300 };
                // cimgui.ImDrawList_AddLine(self.draw_list, v1, v2, line_color, 1);

                const radius = 6;
                const segments = 4;
                cimgui.ImDrawList_AddNgonFilled(
                    self.draw_list,
                    .{ .x = self.base.x + x, .y = self.base.y + y },
                    radius,
                    color,
                    segments,
                );

                var label: [80]u8 = undefined;
                const bytes_written = std.fmt.bufPrint(&label, format, format_args) catch @panic("format failed");
                const text_begin = &label[0];
                const text_end = &label[bytes_written.len];
                cimgui.ImDrawList_AddText_Vec2(
                    self.draw_list,
                    .{ .x = self.base.x + x + border_size, .y = self.base.y + y + border_size },
                    text_color,
                    text_begin,
                    text_end,
                );
            }
        };
        const draw = Draw{ .draw_list = draw_list_flame, .base = flame_cursor_pos };

        const width = flame_region_size.x / @as(f32, @floatFromInt(grid_x));
        const height = flame_region_size.y / @as(f32, @floatFromInt(grid_y));

        draw.span(0, 0, flame_region_size.x, height, "main()", .{});

        for ([_]usize{ 5, 15 }, 0..) |xi, i| {
            const x = @as(f32, @floatFromInt(xi)) * width;
            for (0..3) |yi| {
                const yif = @as(f32, @floatFromInt(yi));
                const y = (yif + 1) * height;
                draw.span(x + yif * 10, y, 100 - yif * 20, height, "recursive({d})", .{yi});
            }

            for (0..3) |yi| {
                const yif = @as(f32, @floatFromInt(yi));
                const y = (yif + 1) * height;
                draw.event(x + yif * 10 + 30, y, recursive_color, "counter: {d}", .{yi});
            }

            {
                const x_event = @as(f32, @floatFromInt(xi - 2)) * width;
                draw.event(x_event, 0, main_event_color, "stack: {d}, heap: {d}, global: {d}", .{ 123 + i, 456 + i * 2, 789 + i * 3 });
            }
        }

        // TODO(pwr): pause/resume button.
        // _ = cimgui.igButton("pause", .{ .x = cursor_pos.x, .y = cursor_pos.y });
    }

    // Measurement configuration.
    {
        // const Variable = struct {
        //     name: []const u8,
        // };

        // const variables =

        _ = cimgui.igBegin("measurement configuration", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();

        const draw_list = cimgui.igGetWindowDrawList();
        const margin_right = 4;

        // TODO(pwr): mutable array to allow toggling events and associated measurments.
        var event_active = true;
        if (cimgui.igCheckbox("##event_active", &event_active)) {}

        const radius = 6;
        cimgui.igSameLine(0, margin_right + radius);
        {
            var cursor_pos: cimgui.ImVec2 = undefined;
            cimgui.igGetCursorScreenPos(&cursor_pos);
            cursor_pos.y += font_size * 0.75;
            const segments = 4;
            cimgui.ImDrawList_AddNgonFilled(draw_list, cursor_pos, radius, main_event_color, segments);
        }

        if (cimgui.igTreeNodeEx_Str("main_event", cimgui.ImGuiTreeNodeFlags_DefaultOpen)) {
            defer cimgui.igTreePop();

            {
                var is_active = true;
                if (cimgui.igCheckbox("##stack_variable", &is_active)) {}
                cimgui.igSameLine(0, margin_right);
                if (cimgui.igTreeNodeEx_Str("stack", cimgui.ImGuiTreeNodeFlags_DefaultOpen)) {
                    defer cimgui.igTreePop();
                    cimgui.igText("uint8_t");
                    cimgui.igText("unit: ms");
                    cimgui.igText("min: 0");
                    cimgui.igText("max: 1000");
                    cimgui.igText("stack_base_pointer: -80");
                }
            }

            {
                var is_active = true;
                if (cimgui.igCheckbox("##heap_variable", &is_active)) {}
                cimgui.igSameLine(0, margin_right);
                if (cimgui.igTreeNodeEx_Str("heap", cimgui.ImGuiTreeNodeFlags_DefaultOpen)) {
                    defer cimgui.igTreePop();
                    cimgui.igText("int64_t");
                    cimgui.igText("deref_pointer_on_stack: -96");
                }
            }

            {
                var is_active = true;
                if (cimgui.igCheckbox("##global_variable", &is_active)) {}
                cimgui.igSameLine(0, margin_right);
                if (cimgui.igTreeNodeEx_Str("global", cimgui.ImGuiTreeNodeFlags_DefaultOpen)) {
                    defer cimgui.igTreePop();
                    cimgui.igText("int32_t");
                    cimgui.igText("load_address_offset: 0x1b3c");
                }
            }

            {
                var is_active = false;
                if (cimgui.igCheckbox("##inactive", &is_active)) {}
                cimgui.igSameLine(0, margin_right);
                if (cimgui.igTreeNodeEx_Str("inactive", cimgui.ImGuiTreeNodeFlags_None)) {
                    defer cimgui.igTreePop();
                    cimgui.igText("uint8_t");
                    cimgui.igText("stack_base_pointer: -64");
                }
            }
        }

        var recursive_active = true;
        if (cimgui.igCheckbox("##recursive_active", &recursive_active)) {}
        cimgui.igSameLine(0, margin_right);

        cimgui.igSameLine(0, margin_right + radius);
        {
            var cursor_pos: cimgui.ImVec2 = undefined;
            cimgui.igGetCursorScreenPos(&cursor_pos);
            cursor_pos.y += font_size * 0.75;
            const segments = 4;
            cimgui.ImDrawList_AddNgonFilled(draw_list, cursor_pos, radius, recursive_color, segments);
        }

        if (cimgui.igTreeNodeEx_Str("recursive", cimgui.ImGuiTreeNodeFlags_DefaultOpen)) {
            defer cimgui.igTreePop();

            {
                var is_active = true;
                if (cimgui.igCheckbox("##counter", &is_active)) {}
                cimgui.igSameLine(0, margin_right);
                if (cimgui.igTreeNodeEx_Str("counter", cimgui.ImGuiTreeNodeFlags_DefaultOpen)) {
                    defer cimgui.igTreePop();
                    cimgui.igText("uint64_t");
                    cimgui.igText("stack_base_pointer: -64");
                }
            }
        }
    }

    // Calibration configuration.
    {
        // const Variable = struct {
        //     name: []const u8,
        // };

        // const variables =

        _ = cimgui.igBegin("calibration", null, cimgui.ImGuiWindowFlags_None);
        defer cimgui.igEnd();

        _ = cimgui.igLabelText("##", "TODO");
        // TODO(pwr):
    }
}

fn drawGrid(draw_list: *cimgui.ImDrawList, grid_x: usize, grid_y: usize, region_size: cimgui.ImVec2, cursor_pos: cimgui.ImVec2, font_size: f32) void {
    const grid_color = cimgui.igGetColorU32_Vec4(.{ .x = 0.3, .y = 0.3, .z = 0.3, .w = 1 });

    for (0..grid_x + 1) |i| {
        const x = @as(f32, @floatFromInt(i)) * region_size.x / @as(f32, @floatFromInt(grid_x));
        cimgui.ImDrawList_AddLine(
            draw_list,
            .{ .x = cursor_pos.x + x, .y = cursor_pos.y },
            .{ .x = cursor_pos.x + x, .y = cursor_pos.y + region_size.y },
            grid_color,
            1,
        );

        var line_label_buffer: [20]u8 = undefined;
        const bytes_written = std.fmt.formatIntBuf(&line_label_buffer, i, 10, .lower, .{});
        const text_begin = &line_label_buffer[0];
        const text_end = &line_label_buffer[bytes_written];
        cimgui.ImDrawList_AddText_Vec2(
            draw_list,
            .{ .x = cursor_pos.x + x, .y = cursor_pos.y + region_size.y - font_size },
            grid_color,
            text_begin,
            text_end,
        );
    }

    for (0..grid_y + 1) |i| {
        const y = @as(f32, @floatFromInt(i)) * region_size.y / @as(f32, @floatFromInt(grid_y));
        cimgui.ImDrawList_AddLine(
            draw_list,
            .{ .x = cursor_pos.x, .y = cursor_pos.y + y },
            .{ .x = cursor_pos.x + region_size.x, .y = cursor_pos.y + y },
            grid_color,
            1,
        );

        var line_label_buffer: [20]u8 = undefined;
        const bytes_written = std.fmt.formatIntBuf(&line_label_buffer, grid_y - i, 10, .lower, .{});
        const text_begin = &line_label_buffer[0];
        const text_end = &line_label_buffer[bytes_written];
        cimgui.ImDrawList_AddText_Vec2(
            draw_list,
            .{ .x = cursor_pos.x, .y = cursor_pos.y + y },
            grid_color,
            text_begin,
            text_end,
        );
    }
}
