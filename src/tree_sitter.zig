pub const tree_sitter = @import("tree_sitter");
pub extern fn tree_sitter_wit() callconv(.c) *tree_sitter.Language;
