const std = @import("std");

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

export fn glfwErrorCallback(err: c_int, description: [*c]const u8) void {
    std.log.err("GLFW Error: {} {s}\n", .{err, description});
}

const AppErrors = error{
    FailedToInitGLFW
};

pub fn main() !void {
    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);

    if (glfw.glfwInit() == glfw.GL_FALSE) {
        std.log.warn("Failed to initialize GLFW\n", .{});
        return AppErrors.FailedToInitGLFW;
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
