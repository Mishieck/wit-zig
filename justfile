clone-wit:
    git clone https://github.com/bytecodealliance/tree-sitter-wit

test-json:
    zig build test -- src/json.zig

test-types:
    zig build test -- src/types.zig
