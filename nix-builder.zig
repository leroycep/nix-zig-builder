const std = @import("std");

const Options = struct {
    // nix store path to zig; e.g. `/nix/store/dzzdjvlzv7jmhs05sxj03nx8spgfchj3-zig-0.10.0-dev.3027+0e26c6149`
    zig: []const u8,

    /// path to directory containing `build.zig`
    src: []const u8,

    /// path to output directory
    out: []const u8,

    /// arguments that will be passed onto `zig build`
    args: [][]const u8,

    global_cache: []const u8,
    local_cache: []const u8,
};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const opts = try getOptions(&arena);

    var args = std.ArrayList([]const u8).init(arena.allocator());
    try args.appendSlice(&.{ opts.zig, "build" });
    try args.appendSlice(&.{ "--global-cache-dir", opts.global_cache });
    try args.appendSlice(&.{ "--cache-dir", opts.local_cache });
    try args.appendSlice(&.{ "--prefix", opts.out });
    try args.appendSlice(opts.args);

    var exec_string = std.ArrayList(u8).init(arena.allocator());
    for (args.items) |arg, i| {
        if (i != 0) try exec_string.append(' ');
        try exec_string.writer().print("{}", .{std.zig.fmtEscapes(arg)});
    }
    std.log.info("exec {s}", .{exec_string.items});

    var zig_build = std.ChildProcess.init(args.items, arena.allocator());
    zig_build.cwd = opts.src;

    switch (try zig_build.spawnAndWait()) {
        .Exited => |exit_code| {
            std.log.info("`zig build` exited with {}", .{exit_code});
            return exit_code;
        },
        else => |term| {
            std.log.info("`zig build` terminated with {}", .{term});
            return 1;
        },
    }
    return 0;
}

fn getOptions(arena: *std.heap.ArenaAllocator) !Options {
    const env = try std.process.getEnvMap(arena.allocator());
    const args = try std.process.argsAlloc(arena.allocator());
    const cwd = try std.process.getCwdAlloc(arena.allocator());

    const zig_path = env.get("zig") orelse return error.NoZigPath;

    return Options{
        .zig = try std.fs.path.join(arena.allocator(), &.{ zig_path, "bin", "zig" }),
        .src = env.get("src") orelse return error.NoSrcDir,
        .out = env.get("out") orelse return error.NoOutDir,
        .args = args[1..],

        // TODO: Point to directory where builds can actually be cached
        .global_cache = try std.fs.path.join(arena.allocator(), &.{ cwd, "zig-global-cache" }),
        .local_cache = try std.fs.path.join(arena.allocator(), &.{ cwd, "zig-local-cache" }),
    };
}
