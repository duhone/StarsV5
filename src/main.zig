const std = @import("std");

const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
    @cDefine("GLFW_EXPOSE_NATIVE_WIN32", "1");
    @cDefine("GLFW_EXPOSE_NATIVE_WGL", "1");
    @cInclude("GLFW/glfw3native.h");
});

const vulkanDevice = @import("VulkanDevice.zig");

export fn glfwErrorCallback(err: c_int, description: [*c]const u8) void {
    std.log.err("GLFW Error: {} {s}\n", .{ err, description });
}

const AppErrors = error{FailedToInit};

pub fn glfwKeyCallback(window: ?*glfw.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;

    if ((key == glfw.GLFW_KEY_ESCAPE) and (action == glfw.GLFW_PRESS)) {
        glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
    }
}

pub fn main() !void {
    @setFloatMode(.Optimized);

    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);

    if (glfw.glfwInit() == glfw.GL_FALSE) {
        std.log.warn("Failed to initialize GLFW\n", .{});
        return AppErrors.FailedToInit;
    }

    if (glfw.glfwVulkanSupported() == glfw.GL_FALSE) {
        std.log.err("GLFW Failed to find vulkan loader\n", .{});
        return AppErrors.FailedToInit;
    }

    // TODO should run on multiple monitors, can just dup to each one.
    // I don't have a multiple monitor setup to work on that.
    const primaryMonitor = glfw.glfwGetPrimaryMonitor();

    const videoMode: *const glfw.GLFWvidmode = glfw.glfwGetVideoMode(primaryMonitor);

    glfw.glfwWindowHint(glfw.GLFW_RED_BITS, videoMode.redBits);
    glfw.glfwWindowHint(glfw.GLFW_GREEN_BITS, videoMode.greenBits);
    glfw.glfwWindowHint(glfw.GLFW_BLUE_BITS, videoMode.blueBits);
    glfw.glfwWindowHint(glfw.GLFW_REFRESH_RATE, videoMode.refreshRate);
    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);

    var window = glfw.glfwCreateWindow(videoMode.width, videoMode.height, "Stars V5", primaryMonitor, null);
    if (window == null) {
        glfw.glfwTerminate();
    }

    var extensionCount: c_uint = 0;
    var extensions: [*c][*c]const u8 = glfw.glfwGetRequiredInstanceExtensions(&extensionCount);
    vulkanDevice.initVulkan(extensions, extensionCount, window) catch {
        std.log.err("Failed to initialize vulkan\n", .{});
        return AppErrors.FailedToInit;
    };

    _ = glfw.glfwSetKeyCallback(window, glfwKeyCallback);

    while (glfw.glfwWindowShouldClose(window) == 0) {
        glfw.glfwPollEvents();
    }

    vulkanDevice.deInitVulkan();
    glfw.glfwTerminate();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
