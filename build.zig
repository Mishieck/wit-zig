const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("wit_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "wit_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "wit_zig", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    // Add tree-sitter dependency
    const tree_sitter = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("tree_sitter", tree_sitter.module("tree_sitter"));

    // Bundle tree-sitter-wit grammar directly by compiling parser.c
    exe.addCSourceFile(.{
        .file = b.path("tree-sitter-wit/src/parser.c"),
        .flags = &[_][]const u8{ "-std=c11", "-fno-sanitize=undefined" },
    });
    exe.linkLibC();

    const scanner_path = b.path("tree-sitter-wit/src/scanner.c");
    exe.addCSourceFile(.{
        .file = scanner_path,
        .flags = &[_][]const u8{ "-std=c11", "-fno-sanitize=undefined" },
    });

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
