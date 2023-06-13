const std = @import("std");
const l = @import("lexer.zig");

pub const Repl = struct {
    const Self = @This();

    reader: std.fs.File.Reader = undefined,
    writer: std.fs.File.Writer = undefined,

    pub fn init(reader: std.fs.File.Reader, writer: std.fs.File.Writer) Self {
        var repl = Self{
            .reader = reader,
            .writer = writer,
        };

        return repl;
    }

    pub fn start(self: *Self) !void {
        const hello = "Hello REPL!";
        const instruction = "Enter a monkey-lang expression!";
        const prompt = ">> ";
        try self.writer.print("{s}\n{s}\n{s}", .{hello, instruction, prompt});

        var buf: [10_000]u8 = undefined; // TODO: better choice for size

        if (try self.reader.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            var lexer = l.Lexer.init(user_input);
            var token = lexer.nextToken();
            while(token != l.Token.eof) {
                try self.writer.print("{any}\n", .{token});
                token = lexer.nextToken();
            }
        }
    }
};
