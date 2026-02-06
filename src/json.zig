const std = @import("std");
const heap = std.heap;
const fs = std.fs;
const json = std.json;
const debug = std.debug;
const mem = std.mem;
const testing = std.testing;

const Todo = json.Value;

// Top-level WIT JSON structure
pub const WitJson = struct {
    packages: []Todo,
    interfaces: []Todo,
    types: []Todo,
    worlds: []World,
};

pub const Package = struct {
    name: []const u8,
    interfaces: []const []const u8,
    docs: ?[]const u8,
};

pub const World = struct {
    name: []const u8,
    imports: Todo,
    exports: Todo,
    // docs: ?[]const u8,
    // includes: ?[]const []const u8,
    package: usize,
};

pub const Import = struct {
    kind: ImportKind,
    name: []const u8,
    interface: ?[]const u8,
    func: ?Func,
    docs: ?[]const u8,
};

pub const Export = struct {
    kind: ExportKind,
    name: []const u8,
    interface: ?[]const u8,
    func: ?Func,
    alias: ?Alias,
    docs: ?[]const u8,
};

pub const ImportKind = enum {
    interface,
    function,
};

pub const ExportKind = enum {
    interface,
    function,
    alias,
};

pub const Interface = struct {
    name: []const u8,
    types: []TypeDef,
    functions: []Func,
    docs: ?[]const u8,
    includes: ?[]const []const u8,
};

pub const TypeDef = struct {
    name: []const u8,
    kind: TypeKind,
    docs: ?[]const u8,
};

pub const TypeKind = union(enum) {
    record: Record,
    flags: Flags,
    variant: Variant,
    enum_: Enum,
    union_: Union,
    resource: Resource,
    handle: Handle,
    tuple: Tuple,
    option: BoxedType,
    result: Result,
    list: BoxedType,
    future: BoxedType,
    stream: Stream,
    type: BoxedType,
    unknown: void,
    string: String,
    char: void,
    bool: void,
    u8: void,
    u16: void,
    u32: void,
    u64: void,
    s8: void,
    s16: void,
    s32: void,
    s64: void,
    float32: void,
    float64: void,

    pub const Record = struct {
        fields: []Field,
    };

    pub const Field = struct {
        name: []const u8,
        ty: TypeRef,
        docs: ?[]const u8,
    };

    pub const Flags = struct {
        flags: []Flag,
        repr: []const u8,
    };

    pub const Flag = struct {
        name: []const u8,
        docs: ?[]const u8,
    };

    pub const Variant = struct {
        cases: []Case,
    };

    pub const Case = struct {
        name: []const u8,
        ty: ?TypeRef,
        docs: ?[]const u8,
    };

    pub const Enum = struct {
        cases: []EnumCase,
        repr: []const u8,
    };

    pub const EnumCase = struct {
        name: []const u8,
        docs: ?[]const u8,
    };

    pub const Union = struct {
        cases: []UnionCase,
    };

    pub const UnionCase = struct {
        ty: TypeRef,
        docs: ?[]const u8,
    };

    pub const Resource = struct {
        functions: []Func,
    };

    pub const Handle = struct {
        resource: TypeRef,
    };

    pub const Tuple = struct {
        types: []TypeRef,
    };

    pub const BoxedType = struct {
        element: TypeRef,
    };

    pub const Result = struct {
        ok: ?TypeRef,
        err: ?TypeRef,
    };

    pub const Stream = struct {
        element: TypeRef,
        end: ?TypeRef,
    };

    pub const String = struct {
        repr: []const u8,
    };
};

pub const TypeRef = union(enum) {
    name: []const u8,
    primitive: PrimitiveType,
    borrowed: BoxedTypeRef,
    owned: BoxedTypeRef,
    @"inline": InlineType,
};

pub const PrimitiveType = enum {
    u8,
    u16,
    u32,
    u64,
    s8,
    s16,
    s32,
    s64,
    float32,
    float64,
    char,
    bool,
    string,
};

pub const BoxedTypeRef = struct {
    element: *const TypeRef,
};

pub const InlineType = struct {
    kind: InlineTypeKind,
};

pub const InlineTypeKind = union(enum) {
    record: TypeKind.Record,
    variant: TypeKind.Variant,
    enum_: TypeKind.Enum,
    union_: TypeKind.Union,
    tuple: TypeKind.Tuple,
    flags: TypeKind.Flags,
};

pub const Func = struct {
    name: []const u8,
    params: []Param,
    results: Results,
    docs: ?[]const u8,
};

pub const Param = struct {
    name: []const u8,
    ty: TypeRef,
    docs: ?[]const u8,
};

pub const Results = union(enum) {
    unnamed: TypeRef,
    named: []NamedResult,
    anon: AnonResult,
};

pub const NamedResult = struct {
    name: []const u8,
    ty: TypeRef,
    docs: ?[]const u8,
};

pub const AnonResult = struct {
    types: []TypeRef,
};

pub const Alias = struct {
    kind: AliasKind,
    target: []const u8,
    docs: ?[]const u8,
};

pub const AliasKind = enum {
    interface,
    world,
    function,
};

// JSON parsing helper
// pub fn parseWitJson(allocator: std.mem.Allocator, json_str: []const u8) !*const WitJson {
//     var parsed = try std.json.parseFromSlice(WitJson, allocator, json_str, .{
//         .ignore_unknown_fields = true,
//         .duplicate_field_behavior = .use_first,
//     });

//     defer parsed.deinit();

//     const wit_json = try allocator.create(WitJson);
//     wit_json.* = parsed.value;

//     return wit_json;
// }

pub fn parseWitJson(allocator: std.mem.Allocator, json_str: []const u8) !*WitJson {
    var json_value = try std.json.parseFromSlice(json.Value, allocator, json_str, .{});
    defer json_value.deinit();

    // Use parseFromValue with custom options
    const options = std.json.ParseOptions{
        .ignore_unknown_fields = true,
        .duplicate_field_behavior = .use_first,
    };

    var parsed = try std.json.parseFromValue(WitJson, allocator, json_value.value, options);

    defer parsed.deinit();

    const wit_json = try allocator.create(WitJson);
    wit_json.* = parsed.value;

    return wit_json;
}

test "json" {
    debug.print("Starting!\n", .{});
    const allocator = testing.allocator;
    const json_wit = @embedFile("./example.json");
    const parsed = try parseWitJson(allocator, json_wit);
    defer allocator.destroy(parsed);
    debug.print("Done!\n", .{});
}
