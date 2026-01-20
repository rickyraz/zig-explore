// =============================================================================
// ERROR HANDLING: Zig vs C vs Rust
// =============================================================================
//
// MENTAL MODEL:
// - C: Return codes (-1, NULL, errno). Easy to ignore. No enforcement.
// - Rust: Result<T, E> dan Option<T>. Harus di-handle, tapi verbose.
// - Zig: Error union (T!E). Mirip Rust tapi dengan syntax lebih ringan.
//        Error HARUS di-handle, compiler enforce ini.
//
// KEY INSIGHT:
// Zig errors adalah VALUES, bukan exceptions.
// Tidak ada stack unwinding, tidak ada hidden control flow.
// Kamu selalu bisa lihat di kode kapan error bisa terjadi.
// =============================================================================

const std = @import("std");

// =============================================================================
// ERROR SETS
// =============================================================================
// Error di Zig adalah enum-like values yang bisa di-combine
//
// Mirip dengan:
// - Rust: enum Error { Variant1, Variant2 }
// - C: #define ERROR_1 1, #define ERROR_2 2
//
// Tapi Zig bisa merge error sets dengan operator ||
// =============================================================================

// Define custom error set
const FileError = error{
    NotFound,
    PermissionDenied,
    DiskFull,
};

const NetworkError = error{
    ConnectionRefused,
    Timeout,
    DnsLookupFailed,
};

// Combine error sets! Ini tidak bisa di Rust/C
const IoError = FileError || NetworkError;

// =============================================================================
// ERROR UNION TYPE
// =============================================================================
// Syntax: ReturnType!ErrorType atau !ReturnType (infer error type)
//
// Comparison:
// - C:   int result; if (result == -1) { /* error */ }
// - Rust: Result<i32, Error>
// - Zig:  i32!Error atau !i32
// =============================================================================

// Explicit error type
fn divide(a: i32, b: i32) error{DivisionByZero}!i32 {
    if (b == 0) {
        return error.DivisionByZero;
    }
    return @divTrunc(a, b);
}

// Inferred error type (compiler figures out possible errors)
fn readConfig(path: []const u8) ![]const u8 {
    _ = path;
    // Compiler akan infer semua possible errors dari operasi di dalam
    return error.NotFound;
}

// =============================================================================
// ERROR HANDLING OPERATORS
// =============================================================================
// Zig punya beberapa cara handle error, dari strict sampai "yolo"
// =============================================================================

pub fn errorHandlingDemo() !void {
    // ----- TRY -----
    // Propagate error ke caller (mirip Rust's ?)
    // Kalau error, langsung return error tersebut
    const result1 = try divide(10, 2);
    std.debug.print("10 / 2 = {d}\n", .{result1});

    // ----- CATCH -----
    // Handle error dengan default value
    // Mirip Rust's unwrap_or()
    const result2 = divide(10, 0) catch |err| blk: {
        std.debug.print("Error: {}\n", .{err});
        break :blk 0; // Return default value
    };
    std.debug.print("Result with catch: {d}\n", .{result2});

    // Catch dengan simple default
    const result3 = divide(10, 0) catch 0;
    _ = result3;

    // ----- ORELSE -----
    // Untuk optional types (mirip catch tapi untuk null)
    const maybe_value: ?i32 = null;
    const value = maybe_value orelse 42;
    _ = value;

    // ----- IF ERROR -----
    // Pattern match on error
    if (divide(10, 0)) |success| {
        std.debug.print("Success: {d}\n", .{success});
    } else |err| {
        std.debug.print("Failed with: {}\n", .{err});
    }
}

// =============================================================================
// DEFER dan ERRDEFER
// =============================================================================
// defer: SELALU jalankan saat keluar scope
// errdefer: Jalankan HANYA kalau function return error
//
// Ini SANGAT powerful untuk resource cleanup
// C tidak punya ini (harus manual)
// Rust pakai Drop trait (implicit)
// Zig explicit tapi lebih flexible
// =============================================================================

fn openResource() !*i32 {
    // Simulate resource allocation
    return error.NotFound;
}

fn closeResource(ptr: *i32) void {
    _ = ptr;
    std.debug.print("Resource closed\n", .{});
}

pub fn deferDemo() !void {
    // defer - always runs
    {
        std.debug.print("Start scope\n", .{});
        defer std.debug.print("End scope (defer)\n", .{});
        std.debug.print("Middle of scope\n", .{});
    }
    // Output:
    // Start scope
    // Middle of scope
    // End scope (defer)

    // Multiple defers run in REVERSE order (LIFO)
    {
        defer std.debug.print("1\n", .{});
        defer std.debug.print("2\n", .{});
        defer std.debug.print("3\n", .{});
    }
    // Output: 3, 2, 1
}

pub fn errdeferDemo() !void {
    // errdefer - only runs if function returns error
    // Perfect untuk cleanup saat initialization gagal

    var resource1: ?*i32 = null;
    var resource2: ?*i32 = null;

    resource1 = openResource() catch null;
    // Kalau openResource kedua gagal, cleanup resource1
    errdefer if (resource1) |r| closeResource(r);

    resource2 = openResource() catch null;
    errdefer if (resource2) |r| closeResource(r);

    // Kalau sampai sini tanpa error, errdefer TIDAK jalan
    // Resources akan di-manage di tempat lain

    // _ = resource1;
    // _ = resource2;
}

// =============================================================================
// COMPARISON: Error Handling Verbosity
// =============================================================================
//
// C - Verbose dan easy to forget:
//   int fd = open("file.txt", O_RDONLY);
//   if (fd == -1) {
//       perror("open");
//       return -1;
//   }
//   // Easy to forget check!
//
// Rust - Safe tapi verbose:
//   let content = std::fs::read_to_string("file.txt")?;
//   // atau
//   let content = match std::fs::read_to_string("file.txt") {
//       Ok(c) => c,
//       Err(e) => return Err(e.into()),
//   };
//
// Zig - Concise dan safe:
//   const content = try std.fs.cwd().readFile("file.txt");
//   // Compiler WAJIBKAN handle error, tapi syntax ringan
// =============================================================================

// =============================================================================
// UNREACHABLE - Assert Impossible State
// =============================================================================
// unreachable = "ini seharusnya tidak mungkin tercapai"
// Kalau tercapai saat runtime = crash (in debug mode)
// Compiler bisa optimize based on this
// =============================================================================

fn processValue(x: i32) i32 {
    if (x > 0) return x * 2;
    if (x < 0) return x * -2;
    if (x == 0) return 0;

    // Compiler tahu ini unreachable, tapi kita explicit
    unreachable;
}

test "error handling" {
    // Test divide success
    const result = try divide(10, 2);
    try std.testing.expectEqual(@as(i32, 5), result);

    // Test divide error
    const err_result = divide(10, 0);
    try std.testing.expectError(error.DivisionByZero, err_result);
}
