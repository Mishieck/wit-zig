const std = @import("std");
const heap = std.heap;
const fs = std.fs;
const json = std.json;
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

pub const PackageJson = struct {
    types: []json.Value,
    interfaces: []json.Value,
    worlds: []json.Value,
    packages: []json.Value,
};

pub const Type = struct {
    name: Todo,
    kind: Todo,
    owner: Todo,
    docs: ?Todo,
};

pub const TypeKind = union(enum) {
    bool,
    u8,
    u16,
    u32,
    u64,
    s8,
    s16,
    s32,
    s64,
    f32,
    f64,
    char,
    string,
    name: []const u8,
    list: Type,
    map: Todo,
    fixed_length_list: *const Todo,
    handle: Todo,
    resource: Todo,
    record: Todo,
    flags: Todo,
    variant: Todo,
    tuple: Todo,
    @"enum": Todo,
    option: Todo,
    result: Todo,
    future: Todo,
    stream: ?Type,
    error_context,
};

const Todo = json.Value;

test PackageJson {
    const allocator = testing.allocator;
    const file_path = "./src/example.json";
    const cwd = fs.cwd();
    const file = try cwd.openFile(file_path, .{});
    defer file.close();
    const wit_json = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(wit_json);
    const parsed = try json.parseFromSlice(PackageJson, allocator, wit_json, .{});
    defer parsed.deinit();
    debug.print("{}", .{parsed.value});
}
