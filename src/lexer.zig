const std = @import("std");

const Token = union(enum) {
    // special
    illegal: void,
    eof: void,

    // identifiers and literals
    ident: []const u8,
    int: i64,

    // operators
    assign: void,
    plus: void,

    // delimiters
    comma: void,
    semicolon: void,
    lparen: void,
    rparen: void,
    lbrace: void,
    rbrace: void,

    // keywords
    function: void,
    let: void,
};

const Lexer = struct {
    const Self = @This();
    input: []const u8 = undefined,
    position: usize = 0, // current position in input (points to current char)
    read_position: usize = 0, // current reading position in input (after current char)
    ch: u8 = undefined, // current char under examination

    pub fn init(input: []const u8) Self {
        var lexer = Self{ .input = input };
        readChar(&lexer);

        return lexer;
    }

    pub fn nextToken(self: *Self) Token {
        var token: Token = .illegal;
        token = switch (self.ch) {
            '=' => .assign,
            '+' => .plus,
            ',' => .comma,
            ';' => .semicolon,
            '(' => .lparen,
            ')' => .rparen,
            '{' => .lbrace,
            '}' => .rbrace,
            0 => .eof,
            else => .illegal,
        };
        readChar(self);

        return token;
    }

    pub fn readChar(self: *Self) void {
        if (self.read_position >= self.input.len) {
            self.ch = 0;
        } else {
            self.ch = self.input[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
    }
};

test "lexer test: =+(){},;" {
    const input = "=+(){},;";
    const expected_tokens = [_]Token{ .assign, .plus, .lparen, .rparen, .lbrace, .rbrace, .comma, .semicolon, .eof };

    var lexer = Lexer.init(input);
    var index: usize = 0;
    while (index < expected_tokens.len) : (index += 1) {
        var token = lexer.nextToken();
        var expected_token = expected_tokens[index];

        try std.testing.expectEqual(expected_token, token);
    }
}

test "lexer test: ====)));" {
    const input = "====)));";
    const expected_tokens = [_]Token{ .assign, .assign, .assign, .assign, .rparen, .rparen, .rparen, .semicolon, .eof };

    var lexer = Lexer.init(input);
    var index: usize = 0;
    while (index < expected_tokens.len) : (index += 1) {
        var token = lexer.nextToken();
        var expected_token = expected_tokens[index];

        try std.testing.expectEqual(expected_token, token);
    }
}
