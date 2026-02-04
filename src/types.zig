//! Reference:  https://github.com/bytecodealliance/wasm-tools/blob/main/crates/wit-parser/src/ast.rs

/// Representation of a single WIT `*.wit` file and nested packages.
pub const Package = struct {
    /// Optional `package foo:bar;` header
    id: ?PackageName,
    /// Other AST items.
    declarations: DeclarationList,
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

pub const Declaration = union(enum) {
    interface: *const Interface,
    world: *const World,
    use: *const ToplevelUse,
    package: *const Package,
};

pub const PackageName = struct {
    docs: *const Docs,
    namespace: Id,
    name: Id,
    version: ?*const Version,
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
    ty: Type,
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
    list: Type,
    map: Map,
    fixed_length_list: *const FixedLengthList,
    handle: Handle,
    resource: Resource,
    record: Record,
    flags: Flags,
    variant: Variant,
    tuple: Tuple,
    @"enum": Enum,
    option: Option,
    result: Result,
    future: Future,
    stream: ?Type,
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
    ty: Type,
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
    ty: ?Type,
};

pub const Enum = []*const EnumCase;

pub const EnumCase = struct {
    docs: Docs,
    name: Id,
};

pub const Option = Type;
pub const List = Type;

pub const Map = struct {
    key: Type,
    value: Type,
};

pub const FixedLengthList = struct {
    ty: Type,
    size: u32,
};

pub const Future = ?Type;
pub const Tuple = []Type;

pub const Result = struct {
    ok: ?Type,
    err: ?Type,
};

pub const NamedFunc = struct {
    docs: Docs,
    attributes: Attribute,
    name: Id,
    func: *const Func,
};

pub const ParamList = []*Param;
pub const Param = struct { Id, Type };

pub const Func = struct {
    async: bool,
    params: ParamList,
    result: ?Type,
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
