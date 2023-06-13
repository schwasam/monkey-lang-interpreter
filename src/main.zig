const std = @import("std");
const r = @import("repl.zig");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var repl = r.Repl.init(stdin, stdout);
    try repl.start();
}

test {
    _ = @import("./lexer.zig");
}

