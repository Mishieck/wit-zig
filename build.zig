const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = addRootModule(b, target, optimize);
    const exe = addMainExecutable(b, target, optimize, mod);

    const test_step = b.step("test", "Run tests");
    addTest(b, test_step, mod);
    addTest(b, test_step, exe.root_module);
}

fn addRootModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = b.addModule("wit_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const tree_sitter = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("tree_sitter", tree_sitter.module("tree_sitter"));

    // Bundle tree-sitter-wit grammar.
    mod.addCSourceFile(createCsourceFile(b, "parser"));
    mod.addCSourceFile(createCsourceFile(b, "scanner"));

    return mod;
}

fn createCsourceFile(
    b: *std.Build,
    comptime filename: []const u8,
) std.Build.Module.CSourceFile {
    return .{
        .file = b.path("./tree-sitter-wit/src/" ++ filename ++ ".c"),
        .flags = &.{ "-std=c11", "-fno-sanitize=undefined" },
    };
}

fn addMainExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "wit_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "wit_zig", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);
    return exe;
}

fn addTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    mod: *std.Build.Module,
) void {
    const tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
