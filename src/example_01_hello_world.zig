const std = @import("std");
const Io = std.Io;
const File = std.Io.File;

pub fn main(init: std.process.Init) !void {
    defer _ = init.arena.reset(.retain_capacity);

    var stdout_buffer: [1_024]u8 = undefined;

    var stdout_writer: File.Writer =
        File.stdout().writer(init.io, &stdout_buffer);

    const writer = &stdout_writer.interface;

    _ = try writer.write("Hello, ");
    _ = try writer.write("World!\n");

    try writer.flush();

    const b: []const u8 = "hello world";

    const a: *const []const u8 = &b;

    const mem: []u8 = try init.arena.allocator().alloc(u8, 64);
    var memp: *const []const u8 = &mem;
    memp = undefined;

    std.debug.print("b string: {any}\n", .{a});
}
