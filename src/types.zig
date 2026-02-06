//! Reference:  https://github.com/bytecodealliance/wasm-tools/blob/main/crates/wit-parser/src/ast.rs

const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const testing = std.testing;
const tree_sitter = @import("./tree_sitter.zig");
const ts = tree_sitter.tree_sitter;
const tsw = tree_sitter.tree_sitter_wit;

/// Representation of a single WIT `*.wit` file and nested packages.
pub const Package = struct {
    const Self = @This();

    /// Optional `package foo:bar;` header
    id: ?*const PackageName,
    /// Other AST items.
    declarations: []PackageDeclaration,

    pub fn fromNode(
        allocator: mem.Allocator,
        source: []const u8,
        node: *const ts.Node,
    ) !*Self {
        const self = try allocator.create(Self);
        const first_child = node.namedChild(0);
        var id: ?*const PackageName = null;
        var declarations = std.array_list.Managed(PackageDeclaration).init(allocator);
        defer declarations.deinit();

        if (first_child) |fc| {
            const kind = fc.kind();
            const is_package_decl = mem.eql(u8, kind, "package_decl");
            if (is_package_decl) id = try PackageName.fromNode(allocator, source, &fc);
        }

        self.* = .{
            .id = id,
            .declarations = try allocator.dupe(PackageDeclaration, declarations.items),
        };

        return self;
    }

    pub fn deinit(self: *Self, allocator: mem.Allocator) void {
        if (self.id) |id| id.deinit(allocator);
        for (self.declarations) |dec| _ = dec;
        allocator.free(self.declarations);
        allocator.destroy(self);
    }
};

/// Stores all of the declarations in a package's scope. In AST terms, this
/// means everything except the `package` declaration that demarcates a package
/// scope. In the traditional implicit format, these are all of the declarations
/// non-`package` declarations in the file:
///
/// ```wit
/// package foo:name;
///
/// /* START DECL LIST */
/// // Some comment...
/// interface i {}
/// world w {}
/// /* END DECL LIST */
/// ```
///
/// In the nested package style, a [`DeclList`] is everything inside of each
/// `package` element's brackets:
///
/// ```wit
/// package foo:name {
///   /* START FIRST DECL LIST */
///   // Some comment...
///   interface i {}
///   world w {}
///   /* END FIRST DECL LIST */
/// }
///
/// package bar:name {
///   /* START SECOND DECL LIST */
///   // Some comment...
///   interface i {}
///   world w {}
///   /* END SECOND DECL LIST */
/// }
/// ```
pub const DeclarationList = []Declaration;

pub const ToplevelDeclaration = union(enum) {
    package: *const Package,
    interface: *const Interface,
    world: *const World,
    use: *const ToplevelUse,
};

pub const PackageDeclaration = union(enum) {
    package: *const Package,
    interface: *const Interface,
    world: *const World,
    use: *const ToplevelUse,
};

pub const Declaration = union(enum) {
    interface: *const Interface,
    world: *const World,
    use: *const ToplevelUse,
    package: *const Package,

    // pub fn fromNode(allocator: mem.Allocator, node: *const ts.Node) !*Declaration {
    //     _ = allocator;
    //     _ = node;
    // }
};

pub const PackageName = struct {
    docs: Docs,
    namespace: Id,
    name: Id,
    version: ?*Version,

    pub fn fromNode(
        allocator: mem.Allocator,
        source: []const u8,
        node: *const ts.Node,
    ) !*PackageName {
        const self = try allocator.create(PackageName);
        var docs = std.array_list.Managed([]const u8).init(allocator);
        defer docs.deinit();
        errdefer docs.deinit();

        var cursor = node.tree.walk();
        defer cursor.destroy();
        errdefer cursor.destroy();
        const named_children = try node.namedChildren(&cursor, allocator);
        defer allocator.free(named_children);
        var text_components: [3][]const u8 = undefined;

        for (named_children, 0..) |child, i| {
            text_components[i] = getNodeText(source, &child);
        }

        for (0..(text_components.len - named_children.len)) |i| {
            text_components[named_children.len + i] = "";
        }

        const namespace, const name, const version_string = text_components;

        const version = if (version_string.len > 0) try Version.fromText(
            allocator,
            version_string,
        ) else null;

        self.* = .{
            .docs = try allocator.dupe([]const u8, docs.items),
            .namespace = namespace,
            .name = name,
            .version = version,
        };

        return self;
    }

    pub fn deinit(self: *const PackageName, allocator: mem.Allocator) void {
        allocator.free(self.docs);
        if (self.version) |version| version.deinit(allocator);
        allocator.destroy(self);
    }
};

pub const ToplevelUse = struct {
    attributes: []Attribute,
    item: *const UsePath,
    as: ?Id,
};

pub const World = struct {
    docs: *const Docs,
    attributes: []Attribute,
    name: Id,
    items: []WorldItem,
};

pub const WorldItem = union(enum) {
    import: *const Import,
    @"export": *const Export,
    use: *const Use,
    type: *const TypeDef,
    include: *const Include,
};

pub const Import = struct {
    docs: Docs,
    attributes: []Attribute,
    kind: ExternKind,
};

pub const Export = struct {
    docs: Docs,
    attributes: []Attribute,
    kind: ExternKind,
};

pub const ExternKind = union(enum) {
    interface: *const struct { Id, []InterfaceItem },
    path: UsePath,
    func: *const ExternKindFunc,
};

pub const ExternKindFunc = struct { Id, Func };

pub const Interface = struct {
    docs: Docs,
    attributes: []Attribute,
    name: Id,
    items: []InterfaceItem,
};

pub const WorldOrInterface = enum { world, interface, unknown };

pub const InterfaceItem = union(enum) {
    type_def: *const TypeDef,
    func: *const NamedFunc,
    use: *const Use,
};

pub const Use = struct {
    attributes: []Attribute,
    from: UsePath,
    names: []*const UseName,
};

pub const UsePath = union(enum) {
    id: Id,
    package: *const UsePathPackage,
};

pub const UsePathPackage = struct { id: PackageName, name: Id };
pub const UseName = struct { name: Id, as: ?Id };

pub const Include = struct {
    from: UsePath,
    attributes: []Attribute,
    names: []*const IncludeName,
};

pub const IncludeName = struct { name: Id, as: Id };
pub const Id = []const u8;
pub const Docs = []const []const u8;

pub const TypeDef = struct {
    docs: Docs,
    attributes: []Attribute,
    name: Id,
    ty: *const Type,
};

pub const Type = union(enum) {
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
    name: Id,
    list: *const List,
    map: Map,
    fixed_length_list: *const FixedLengthList,
    handle: Handle,
    resource: Resource,
    record: Record,
    flags: Flags,
    variant: Variant,
    tuple: Tuple,
    @"enum": Enum,
    option: *const Option,
    result: Result,
    future: *const Future,
    stream: *const Stream,
    error_context,
};

pub const Handle = union(enum) {
    own: Id,
    borrow: Id,
};

pub const Resource = []ResourceFunc;

pub const ResourceFunc = union(enum) {
    method: *const NamedFunc,
    static: *const NamedFunc,
    constructor: *const NamedFunc,
};

pub const Record = []Field;

pub const Field = struct {
    docs: Docs,
    name: Id,
    ty: *const Type,
};

pub const Flags = []Flag;

pub const Flag = struct {
    docs: Docs,
    name: Id,
};

pub const Variant = []Case;

pub const Case = struct {
    docs: Docs,
    name: Id,
    ty: ?*const Type,
};

pub const Enum = []*const EnumCase;

pub const EnumCase = struct {
    docs: Docs,
    name: Id,
};

pub const Option = struct { type: *const Type };
pub const List = struct { type: *const Type };
pub const Stream = ?*const Type;

pub const Map = struct {
    key: *const Type,
    value: *const Type,
};

pub const FixedLengthList = struct {
    ty: *const Type,
    size: u32,
};

pub const Future = ?*const Type;
pub const Tuple = []*const Type;

pub const Result = struct {
    ok: ?*const Type,
    err: ?*const Type,
};

pub const NamedFunc = struct {
    docs: Docs,
    attributes: Attribute,
    name: Id,
    func: *const Func,
};

pub const ParamList = []*Param;
pub const Param = struct { Id, *const Type };

pub const Func = struct {
    async: bool,
    params: ParamList,
    result: ?*const Type,
};

pub const Attribute = union(enum) {
    since: Version,
    /// Feature
    unstable: Id,
    deprecated: Version,
};

pub const Version = struct {
    major: u64,
    minor: u64,
    patch: u64,
    pre: ?[]const u8 = null,
    build: ?[]const u8 = null,

    // TODO: Handle SemVer labels
    pub fn fromText(allocator: mem.Allocator, text: []const u8) !*Version {
        const version = try allocator.create(Version);
        var values = mem.splitScalar(u8, text, '.');

        version.* = .{
            .major = try parseVersionNumber(values.next().?),
            .minor = try parseVersionNumber(values.next().?),
            .patch = try parseVersionNumber(values.next().?),
        };

        return version;
    }

    pub fn deinit(self: *Version, allocator: mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn parseVersionNumber(string: []const u8) !u64 {
        return try std.fmt.parseUnsigned(u64, string, 10);
    }
};

fn getNodeText(source: []const u8, node: *const ts.Node) []const u8 {
    const start_byte = node.startByte();
    const end_byte = node.endByte();
    return source[start_byte..end_byte];
}

test Package {
    const allocator = testing.allocator;
    const language = tsw();
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(language);

    const code =
        \\package wit-zig:types@0.0.0;
        \\
        \\interface inter {
        \\    type name = u8; 
        \\}
        \\
        \\world my-world {
        \\    import foo: func() -> string;
        \\    export bar: func(s: string) -> u32;
        \\}
    ;

    // // Parse some source code and get the root node
    const tree = parser.parseString(code, null);
    defer tree.?.destroy();
    const node = tree.?.rootNode();

    var package = try Package.fromNode(allocator, code, &node);
    defer package.deinit(allocator);
}

test PackageName {
    const source = "package wit-zig:types";
    const source_with_version = source ++ "@0.1.2";
    const namespace = "wit-zig";
    const name = "types";

    try testPacakgeName(source, namespace, name, null);
    var result = testPacakgeName(source, namespace, name, .{ 0, 0, 0 });
    try testing.expectError(error.PackageNameHasNoVersion, result);

    try testPacakgeName(source_with_version, namespace, name, .{ 0, 1, 2 });
    result = testPacakgeName(source_with_version, namespace, name, null);
    try testing.expectError(error.PackageNameHasVersion, result);
}

fn testPacakgeName(
    source: []const u8,
    namespace: []const u8,
    name: []const u8,
    version: ?[3]u64,
) !void {
    const allocator = testing.allocator;

    const language = tsw();
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(language);

    // Parse some source code and get the root node
    var tree = parser.parseString(source, null);
    defer tree.?.destroy();
    var node = tree.?.rootNode().namedChild(0).?;
    var package_name = try PackageName.fromNode(allocator, source, &node);
    defer package_name.deinit(allocator);

    try testing.expectEqualStrings(namespace, package_name.namespace);
    try testing.expectEqualStrings(name, package_name.name);

    if (version) |v| {
        if (package_name.version) |pv| {
            for ([3]u64{ pv.major, pv.minor, pv.patch }, 0..) |n, i| {
                try testing.expectEqual(v[i], n);
            }
        } else return error.PackageNameHasNoVersion;
    } else if (package_name.version) |_| return error.PackageNameHasVersion;
}

test Version {
    const allocator = testing.allocator;
    var version = try Version.fromText(allocator, "0.1.2");
    defer version.deinit(allocator);

    try testing.expectEqual(0, version.major);
    try testing.expectEqual(1, version.minor);
    try testing.expectEqual(2, version.patch);
}
