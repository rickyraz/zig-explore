// =============================================================================
// I/O & WRITERGATE: Zig 0.15 Major Changes
// =============================================================================
//
// WRITERGATE adalah perubahan besar di Zig 0.15!
// Reader dan Writer interfaces completely reworked.
//
// SEBELUMNYA (Zig < 0.15):
// - Writer adalah GENERIC type dengan banyak type parameters
// - Error type di-embed dalam generic
// - Allocate buffer internally
//
// SEKARANG (Zig 0.15+):
// - Writer adalah NON-GENERIC vtable-based interface
// - Kamu allocate buffer SENDIRI
// - Lebih explicit, lebih flexible, lebih performant
//
// KENAPA PERUBAHAN INI?
// 1. Performance - up to 2x-15x speedup!
// 2. No generic pollution - tidak perlu `anytype` everywhere
// 3. Precise error handling - tidak perlu `anyerror`
// 4. Better suited for future I/O models (colorless async)
// =============================================================================

const std = @import("std");
const Io = std.Io;

// =============================================================================
// BASIC STDOUT WRITING - Before vs After
// =============================================================================
//
// SEBELUMNYA (Zig < 0.15):
//   const stdout = std.io.getStdOut().writer();
//   try stdout.print("Hello, {s}!\n", .{"World"});
//   // Buffer di-manage internally
//
// SEKARANG (Zig 0.15+):
//   var stdout_buffer: [1024]u8 = undefined;  // KAMU allocate buffer
//   var stdout_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
//   const writer = &stdout_writer.interface;
//   try writer.print("Hello, {s}!\n", .{"World"});
//   try writer.flush();  // JANGAN LUPA FLUSH!
// =============================================================================

pub fn basicWriteDemo(io: Io) !void {
    // Step 1: Allocate buffer (KAMU yang control!)
    var stdout_buffer: [1024]u8 = undefined;

    // Step 2: Create writer dengan buffer
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);

    // Step 3: Get interface pointer untuk operations
    const writer = &stdout_file_writer.interface;

    // Step 4: Write!
    try writer.print("Hello from Zig 0.15!\n", .{});
    try writer.print("The answer is: {d}\n", .{42});

    // Step 5: FLUSH! (Sangat penting, jangan lupa!)
    try writer.flush();
}

// =============================================================================
// FUNCTION DENGAN WRITER PARAMETER - Before vs After
// =============================================================================
//
// SEBELUMNYA (Zig < 0.15):
//   // Harus pakai generic dan anytype
//   fn writeStuff(writer: anytype) !void {
//       try writer.print("stuff", .{});
//   }
//   // Atau dengan full generic:
//   fn writeStuff(writer: std.io.GenericWriter(...)) !void { ... }
//
// SEKARANG (Zig 0.15+):
//   // Concrete type! No generics!
//   fn writeStuff(writer: *Io.Writer) Io.Writer.Error!void {
//       try writer.print("stuff", .{});
//   }
// =============================================================================

// Clean, non-generic function signature!
pub fn writeMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("This is a message\n", .{});
    try writer.print("From a non-generic function!\n", .{});
}

// Sebelumnya harus begini:
// pub fn writeMessageOld(writer: anytype) !void {
//     try writer.print("This is a message\n", .{});
// }
// Problem: anytype = generic pollution, anyerror, susah tooling

// =============================================================================
// STRUCT DENGAN WRITER - Before vs After
// =============================================================================
//
// SEBELUMNYA:
//   const Logger = struct {
//       writer: anytype,  // ERROR! anytype tidak bisa jadi field
//       // Harus pakai generic:
//   };
//   fn Logger(comptime WriterType: type) type { ... }  // Complicated!
//
// SEKARANG:
//   const Logger = struct {
//       writer: *Io.Writer,  // Simple concrete type!
//   };
// =============================================================================

pub const Logger = struct {
    writer: *Io.Writer,
    prefix: []const u8,

    const Self = @This();

    pub fn init(writer: *Io.Writer, prefix: []const u8) Self {
        return .{
            .writer = writer,
            .prefix = prefix,
        };
    }

    pub fn log(self: *Self, message: []const u8) Io.Writer.Error!void {
        try self.writer.print("[{s}] {s}\n", .{ self.prefix, message });
    }

    pub fn logFmt(self: *Self, comptime fmt: []const u8, args: anytype) Io.Writer.Error!void {
        try self.writer.print("[{s}] ", .{self.prefix});
        try self.writer.print(fmt, args);
        try self.writer.print("\n", .{});
    }
};

// =============================================================================
// BUFFERING & FLUSHING
// =============================================================================
// Di Zig 0.15, kamu HARUS manage buffer sendiri.
// Ini berarti:
// 1. Kamu allocate buffer
// 2. Kamu harus FLUSH sebelum buffer keluar scope
// 3. Hati-hati dengan lifetime!
//
// WARNING: Returning writer dengan stack buffer = DANGLING POINTER!
// =============================================================================

// JANGAN LAKUKAN INI - Buffer keluar scope!
// fn createBadWriter() Io.File.Writer {
//     var buffer: [1024]u8 = undefined;  // Stack buffer
//     return .init(.stdout(), io, &buffer);  // DANGER! Dangling pointer
// }

// CORRECT: Pass buffer dari caller
pub fn createWriter(io: Io, buffer: []u8) Io.File.Writer {
    return .init(.stdout(), io, buffer);
}

// =============================================================================
// READING - Similar Changes
// =============================================================================
// Reader juga berubah dengan cara yang sama:
// - Non-generic interface
// - Kamu manage buffer
// =============================================================================

pub fn basicReadDemo(io: Io) !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader: Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const reader = &stdin_reader.interface;

    // Read a line
    var line_buffer: [256]u8 = undefined;
    const line = reader.readUntilDelimiter(&line_buffer, '\n') catch |err| {
        if (err == error.EndOfStream) return;
        return err;
    };

    std.debug.print("You entered: {s}\n", .{line});
}

// =============================================================================
// COMPARISON: Writer Interface
// =============================================================================
//
// SEBELUMNYA (Generic, complex):
//   pub fn GenericWriter(
//       comptime Context: type,
//       comptime WriteError: type,
//       comptime writeFn: fn (Context, []const u8) WriteError!usize,
//   ) type {
//       return struct {
//           context: Context,
//           // ... complex generic machinery
//       };
//   }
//
// SEKARANG (vtable, simple):
//   pub const Writer = struct {
//       ptr: *anyopaque,
//       vtable: *const VTable,
//
//       pub const VTable = struct {
//           write: *const fn (...) Error!void,
//           flush: *const fn (...) Error!void,
//       };
//   };
// =============================================================================

// =============================================================================
// FORMATTING CHANGES (Zig 0.15)
// =============================================================================
//
// Format specifiers berubah:
// - {f} = custom format method (BARU! Sebelumnya automatic)
// - {t} = tags dan error variants
// - {b64} = base64 encoding
// - {} empty braces = ERROR jika struct punya format method
//
// SEBELUMNYA:
//   const Point = struct {
//       x: i32, y: i32,
//       pub fn format(...) !void { ... }
//   };
//   std.debug.print("{}", .{point});  // Auto-call format method
//
// SEKARANG:
//   std.debug.print("{f}", .{point});  // Explicit {f} untuk format method
//   std.debug.print("{}", .{point});   // ERROR!
// =============================================================================

const FormattablePoint = struct {
    x: i32,
    y: i32,

    pub fn format(
        self: FormattablePoint,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Point({d}, {d})", .{ self.x, self.y });
    }
};

pub fn formattingDemo() void {
    const p = FormattablePoint{ .x = 10, .y = 20 };

    // Zig 0.15: Harus pakai {f} untuk custom format
    std.debug.print("Using {{f}}: {f}\n", .{p});

    // {any} tetap bisa dipakai
    std.debug.print("Using {{any}}: {any}\n", .{p});

    // {t} untuk enum tags
    const MyEnum = enum { first, second, third };
    std.debug.print("Enum tag: {t}\n", .{MyEnum.second});
}

// =============================================================================
// FUTURE: COLORLESS I/O
// =============================================================================
//
// Kenapa async/await dihapus dari Zig?
// Zig team memilih pendekatan "colorless I/O" untuk masa depan.
//
// COLORED I/O (JavaScript, Rust async):
//   async function doStuff() { ... }  // "Colored" async
//   function doOther() { ... }        // "Colored" sync
//   // Tidak bisa mix tanpa await!
//
// COLORLESS I/O (Zig future plan):
//   fn doStuff(io: Io) !void { ... }  // Satu function
//   // Caller yang tentukan apakah blocking atau async
//   // Sama function bisa dipakai di mana saja
//
// Dengan interface Io yang baru:
// - Function tidak perlu tau apakah dia async atau sync
// - Caller/runtime yang handle execution model
// - Lebih composable, lebih reusable
// =============================================================================

// =============================================================================
// MIGRATION TIPS
// =============================================================================
//
// 1. Allocate buffer di caller, pass ke writer
// 2. Ganti `anytype` writer dengan `*Io.Writer`
// 3. Ganti `anyerror` dengan `Io.Writer.Error`
// 4. SELALU flush sebelum buffer keluar scope
// 5. Hati-hati dengan lifetime buffer
// 6. Update format specifiers ({} -> {f} untuk custom format)
// 7. std.fs.File reader/writer deprecated - pakai Io interface
// =============================================================================

test "writer interface" {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try writer.print("test {d}", .{42});
    try std.testing.expectEqualStrings("test 42", fbs.getWritten());
}
