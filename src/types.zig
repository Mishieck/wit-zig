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

    pub fn fromNode(allocator: mem.Allocator, node: *const ts.Node) !*Self {
        const self = try allocator.create(Self);
        const first_child = node.namedChild(0);
        var id: ?*const PackageName = null;
        var declarations = std.array_list.Managed(PackageDeclaration).init(allocator);
        defer declarations.deinit();

        if (first_child) |fc| {
            const kind = fc.kind();
            const is_package_decl = mem.eql(u8, kind, "package_decl");
            if (is_package_decl) id = try PackageName.fromNode(allocator, &fc);
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
    version: ?*const Version,

    pub fn fromNode(allocator: mem.Allocator, node: *const ts.Node) !*PackageName {
        _ = node;
        const self = try allocator.create(PackageName);
        var docs = std.array_list.Managed([]const u8).init(allocator);
        defer docs.deinit();
        errdefer docs.deinit();
        _ = &docs;

        self.* = .{
            .docs = try allocator.dupe([]const u8, docs.items),
            .namespace = "",
            .name = "",
            .version = null,
        };

        debug.print("{}", .{self});
        return self;
    }

    pub fn deinit(self: *const PackageName, allocator: mem.Allocator) void {
        allocator.free(self.docs);
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
    pre: ?[]const u8,
    build: ?[]const u8,
};

test Package {
    const allocator = testing.allocator;
    const language = tsw();
    defer language.destroy();

    const parser = ts.Parser.create();
    defer parser.destroy();
    try parser.setLanguage(language);

    const code =
        \\package test:my-package;
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

    var package = try Package.fromNode(allocator, &node);
    defer package.deinit(allocator);
}
