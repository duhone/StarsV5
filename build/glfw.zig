const std = @import("std");

pub fn buildglfw(b: *std.build.Builder, target: *const std.zig.CrossTarget, mode: *const std.builtin.Mode) *std.build.LibExeObjStep {
    const cflags = [_][]const u8{
        // when compiling this lib in debug mode, it seems to add -fstack-protector so if you want to link it
        // with an exe built with -Dtarget=x86_64-windows-msvc you need the line below or you'll get undefined symbols
        "-fno-stack-protector",

        "-D_STDIO_DEFINED",
        "-D_GLFW_WIN32",
        "-D_UNICODE",
        "-DUNICODE",
    };

    const src_dir = "3rdparty/glfw/src";

    const lib = b.addStaticLibrary("glfw3", null);
    lib.linkLibC();

    if (lib.build_mode != .Debug) {
        lib.strip = true;
    }

    lib.addIncludePath("3rdparty/glfw/include");

    const src_files = [_][]const u8{
        "context.c",
        "init.c",
        "input.c",
        "monitor.c",
        "vulkan.c",
        "window.c",
        "win32_init.c",
        "win32_joystick.c",
        "win32_monitor.c",
        "win32_time.c",
        "win32_thread.c",
        "win32_window.c",
        "wgl_context.c",
        "egl_context.c",
        "osmesa_context.c",
    };

    inline for (src_files) |src| {
        lib.addCSourceFile(src_dir ++ "/" ++ src, &cflags);
    }

    lib.setTarget(target.*);
    lib.setBuildMode(mode.*);
    lib.install();

    return lib;
}
