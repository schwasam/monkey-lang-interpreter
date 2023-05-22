const std = @import("std");
const lex = @import("lexer.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("All your {s} are belong to us.\n", .{"tokens"});

    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
    ;

    // zig fmt: off
    const expected_tokens = [_]lex.Token{ 
        .let, lex.Token{ .ident = "five" }, .assign, lex.Token{ .int = 5 }, .semicolon, // let five = 5;
        .let, lex.Token{ .ident = "ten" }, .assign, lex.Token{ .int = 10 }, .semicolon, // let ten = 10;
        .let, lex.Token{ .ident= "add" }, .assign, .function, .lparen, lex.Token{ .ident = "x" }, .comma, lex.Token{ .ident = "y" }, .rparen, .lbrace, // let add = fn(x, y) {
        lex.Token{ .ident = "x" }, .plus, lex.Token{ .ident = "y" }, .semicolon, // x + y;
        .rbrace, .semicolon, // };
        .let, lex.Token{ .ident = "result" }, .assign, lex.Token{ .ident = "add" }, .lparen, lex.Token{ .ident = "five" }, .comma, lex.Token{ .ident = "ten" }, .rparen, .semicolon, // let result = add(five, ten);
        .eof
    };
    // zig fmt: on

    try stdout.print("input:\n------\n{s}\n------\n", .{input});

    var lexer = lex.Lexer.init(input);

    var index: usize = 0;
    while (index < expected_tokens.len) : (index += 1) {
        var token = lexer.nextToken();
        var expected_token = expected_tokens[index];

        switch (token) {
            .ident => try stdout.print("token: {}, ident: {s}, expected: {}\n", .{ token, token.ident, expected_token }),
            .illegal => try stdout.print("token: {}, illegal: {}, expected: {}\n", .{ token, token.illegal, expected_token }),
            else => try stdout.print("token: {}, expected: {}\n", .{ token, expected_token }),
        }
    }

    try bw.flush();
}
