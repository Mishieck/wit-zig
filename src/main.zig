const std = @import("std");
const debug = std.debug;
const assert = debug.assert;

const ts = @import("tree_sitter");

extern fn tree_sitter_wit() callconv(.c) *ts.Language;

pub fn main() !void {
    debug.print("Testing zig_tree_sitter\n", .{});
    // Create a parser for the zig language
    const language = tree_sitter_wit();
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
    assert(std.mem.eql(u8, node.kind(), "source_file"));
    assert(!node.hasError());

    // Create a query and execute it
    var error_offset: u32 = 0;
    const query_string = "(interface_item name: (id) @module)";
    const query = try ts.Query.create(language, query_string, &error_offset);
    defer query.destroy();

    const cursor = ts.QueryCursor.create();
    defer cursor.destroy();
    cursor.exec(query, node);

    // Get the captured node of the first match
    const match = cursor.nextMatch().?;
    const capture = match.captures[0].node;
    assert(std.mem.eql(u8, capture.kind(), "id"));
}
