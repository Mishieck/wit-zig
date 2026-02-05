const std = @import("std");
const debug = std.debug;
const assert = debug.assert;

const wit_zig = @import("wit_zig");
const tree_sitter = wit_zig.tree_sitter;
const ts = tree_sitter.tree_sitter;
const tsw = tree_sitter.tree_sitter_wit;

pub fn main() !void {
    // Create a parser for the zig language
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
    debug.print("Done!\n", .{});
}
