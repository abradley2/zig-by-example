const std = @import("std");

const zig_by_example = @import("zig_by_example");

const layout_file = @embedFile("layout.html");

pub fn main(init: std.process.Init) !void {
    try zig_by_example.example_01_hello_world.main(init);

    const pages_dir = try std.Io.Dir.cwd().openDir(init.io, "pages", .{ .iterate = true });
    defer pages_dir.close(init.io);

    const public_dir = try std.Io.Dir.cwd().openDir(init.io, "docs", .{});
    defer public_dir.close(init.io);

    var scratch_buffer: [1_024]u8 = undefined;

    var pages_dir_iter = pages_dir.iterate();
    while (try pages_dir_iter.next(init.io)) |entry| {
        var page_contents: std.ArrayList(u8) = try .initCapacity(init.gpa, 1_024 * 1_024);
        defer page_contents.deinit(init.gpa);

        {
            const page_file = try pages_dir.openFile(init.io, entry.name, .{});
            var page_file_reader = page_file.reader(init.io, &scratch_buffer);
            try readAll(init.gpa, &page_file_reader.interface, &page_contents);
        }

        const with_layout = try applyLayout(
            init.gpa,
            layout_file,
            std.mem.trim(u8, page_contents.items, "\n"),
        );
        defer init.gpa.free(with_layout);

        var public_file = try public_dir.createFile(init.io, entry.name, .{ .truncate = true });
        var public_file_writer = public_file.writer(init.io, &scratch_buffer);

        try writeAll(&public_file_writer.interface, with_layout);
    }
}

fn applyLayout(allocator: std.mem.Allocator, layout: []const u8, contents: []const u8) error{OutOfMemory}![]const u8 {
    var output_writer: std.ArrayList(u8) = try .initCapacity(allocator, layout.len + contents.len + 64);
    errdefer output_writer.deinit(allocator);

    var layout_iter = std.mem.splitSequence(u8, layout, "{{content}}");

    while (layout_iter.next()) |section| {
        try output_writer.appendSlice(allocator, section);
        if (layout_iter.peek() != null) {
            try output_writer.appendSlice(allocator, contents);
        }
    }

    return try output_writer.toOwnedSlice(allocator);
}

fn writeAll(writer: *std.Io.Writer, output: []const u8) !void {
    var idx: usize = 0;
    while (idx < output.len) : (idx += 1) {
        try writer.writeByte(output[idx]);
        if (writer.buffered().len == writer.buffer.len) try writer.flush();
    }
    if (writer.buffered().len > 0) try writer.flush();
}

fn readAll2(allocator: std.mem.Allocator, reader: *std.Io.Reader, output: *std.ArrayList(u8)) !void {
    while (true) {
        const next = try reader.readSliceAll(reader.buffer) catch |err| switch (err) {
            error.EndOfStream() => reader.buffered(),
            error.ReadFailed => return error.ReadFailed,
        };
        try output.appendSlice(allocator, next);
        if (reader.bufferedLen() < reader.buffer.len) break;
    }
}

fn readAll(allocator: std.mem.Allocator, reader: *std.Io.Reader, output: *std.ArrayList(u8)) error{ ReadFailed, OutOfMemory }!void {
    while (true) {
        reader.fill(reader.buffer.len) catch |err| switch (err) {
            error.EndOfStream => {},
            error.ReadFailed => return error.ReadFailed,
        };
        try output.appendSlice(allocator, reader.buffered());
        if (reader.bufferedLen() < reader.buffer.len) break;
        reader.tossBuffered();
    }
}
