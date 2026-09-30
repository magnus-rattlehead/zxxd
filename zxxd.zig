const std = @import("std");
const hex = "0123456789abcdef";

const row_width = 78;
const bytes_per_row = 16;

fn printRow(interface: *std.Io.Writer, offset: usize, row: []const u8) !void {
    var printbuf: [row_width]u8 = undefined;
    const off: u32 = @intCast(offset);
    var pos: usize = 0;

    for (0..8) |i| {
        const shift: u5 = @intCast((7 - i) * 4);
        printbuf[pos] = hex[(off >> shift) & 0x0f];
        pos += 1;
    }

    printbuf[pos] = ':';
    printbuf[pos + 1] = ' ';
    pos += 2;

    for (0..bytes_per_row) |i| {
        if (i < row.len) {
            const byte = row[i];
            printbuf[pos] = hex[byte >> 4];
            printbuf[pos + 1] = hex[byte & 0x0f];
        } else {
            printbuf[pos] = ' ';
            printbuf[pos + 1] = ' ';
        }
        printbuf[pos + 2] = ' ';
        pos += 3;
    }

    printbuf[pos] = '|';
    pos += 1;

    for (0..bytes_per_row) |i| {
        const byte = if (i < row.len) row[i] else null;
        printbuf[pos] = if (byte) |b|
            if (b >= 0x20 and b <= 0x7e) b else '.'
        else
            ' ';
        pos += 1;
    }

    printbuf[pos] = '|';
    printbuf[pos + 1] = '\n';
    pos += 2;

    try interface.writeAll(printbuf[0..pos]);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdinbuf: [16 * 1024]u8 = undefined;
    var stdoutbuf: [16 * 1024]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(io, &stdinbuf);
    var stdout = std.Io.File.stdout().writerStreaming(io, &stdoutbuf);

    var offset: usize = 0;

    while (true) {
        const row = stdin.interface.peek(16) catch |err| switch (err) {
            error.EndOfStream => {
                const tail = stdin.interface.buffered();
                if (tail.len != 0) {
                    try printRow(&stdout.interface, offset, tail);
                    _ = try stdin.interface.discard(.limited(tail.len));
                }
                break;
            },
            else => return err,
        };
        if (row.len == 0) break;
        try printRow(&stdout.interface, offset, row);
        offset += row.len;
        _ = try stdin.interface.discard(.limited(row.len));
    }

    try stdout.interface.flush();
}
