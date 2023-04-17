const std = @import("std");
const glfw = @import("build/glfw.zig");

pub fn build(b: *std.build.Builder) !void {
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const env_map = try allocator.create(std.process.EnvMap);
    env_map.* = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const vulkanSDKPath = env_map.get("VULKAN_SDK") orelse "";
    const vulkanIncludePath = try std.fmt.allocPrint(allocator, "{s}/include", .{vulkanSDKPath});
    defer allocator.free(vulkanIncludePath);
    try stdout.print("VULKAN SDK {s}\n", .{vulkanIncludePath});
    const vulkanLibraryPath = try std.fmt.allocPrint(allocator, "{s}/Lib", .{vulkanSDKPath});
    defer allocator.free(vulkanLibraryPath);

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("StarsV5", "src/main.zig");
    exe.linkLibC();
    exe.addIncludePath("3rdparty/glfw/include");
    exe.addIncludePath(vulkanIncludePath);
    exe.addLibraryPath(vulkanLibraryPath);
    exe.linkLibrary(glfw.buildglfw(b, &target, &mode));
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("kernel32");
    exe.linkSystemLibrary("vulkan-1");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
