// =============================================================================
//           ZIG FEATURES FOR TCP/IP & UDP IMPLEMENTATION
//                 Props yang Akan Heavy Dipakai
// =============================================================================
//
// Untuk reimplementing TCP/IP stack, Zig sangat cocok karena:
// 1. Packed structs - map langsung ke protocol headers
// 2. Comptime - generate lookup tables, validate protocol constants
// 3. Explicit memory - control buffer allocation
// 4. No hidden allocations - predictable performance
// 5. Easy C interop - integrate dengan OS network APIs
//
// =============================================================================

const std = @import("std");
const mem = std.mem;
const native_endian = @import("builtin").cpu.arch.endian();

// =============================================================================
//                    1. PACKED STRUCTS - Protocol Headers
// =============================================================================
//
// PALING PENTING untuk network programming!
//
// Packed struct = exact memory layout, no padding
// Perfect untuk map binary protocol headers
//
// Network protocols define EXACT byte layouts:
// - IP Header: 20+ bytes dengan specific bit positions
// - TCP Header: 20+ bytes
// - UDP Header: 8 bytes
//
// Dengan packed struct, kamu bisa:
// - Cast raw bytes langsung ke struct
// - Access fields dengan nama (bukan bit shifting manual)
// - Compiler handle bit packing otomatis
// =============================================================================

/// IPv4 Header (RFC 791)
/// Network byte order (big-endian)
pub const IPv4Header = packed struct {
    // Byte 0: Version (4 bits) + IHL (4 bits)
    ihl: u4,          // Internet Header Length (in 32-bit words)
    version: u4,      // Always 4 for IPv4

    // Byte 1: DSCP (6 bits) + ECN (2 bits)
    ecn: u2,          // Explicit Congestion Notification
    dscp: u6,         // Differentiated Services Code Point

    // Bytes 2-3: Total Length
    total_length: u16,

    // Bytes 4-5: Identification
    identification: u16,

    // Bytes 6-7: Flags (3 bits) + Fragment Offset (13 bits)
    fragment_offset_low: u8,
    flags_and_offset_high: u8,  // Contains flags in high 3 bits

    // Byte 8: TTL
    ttl: u8,

    // Byte 9: Protocol
    protocol: u8,

    // Bytes 10-11: Header Checksum
    header_checksum: u16,

    // Bytes 12-15: Source Address
    src_addr: u32,

    // Bytes 16-19: Destination Address
    dst_addr: u32,

    // Options follow if IHL > 5

    pub fn getHeaderLength(self: IPv4Header) u8 {
        return self.ihl * 4; // IHL is in 32-bit words
    }

    pub fn isFragmented(self: IPv4Header) bool {
        const flags = self.flags_and_offset_high >> 5;
        const mf = (flags & 0x1) != 0; // More Fragments
        const offset = self.getFragmentOffset();
        return mf or offset > 0;
    }

    pub fn getFragmentOffset(self: IPv4Header) u16 {
        const high: u16 = @as(u16, self.flags_and_offset_high & 0x1F) << 8;
        return (high | self.fragment_offset_low) * 8; // Offset is in 8-byte units
    }
};

/// TCP Header (RFC 793)
pub const TCPHeader = packed struct {
    src_port: u16,
    dst_port: u16,
    sequence_number: u32,
    ack_number: u32,

    // Data offset (4 bits) + Reserved (3 bits) + Flags (9 bits)
    reserved_and_ns: u4,
    data_offset: u4,    // Header length in 32-bit words
    flags: TCPFlags,

    window_size: u16,
    checksum: u16,
    urgent_pointer: u16,

    // Options follow if data_offset > 5

    pub fn getHeaderLength(self: TCPHeader) u8 {
        return self.data_offset * 4;
    }
};

pub const TCPFlags = packed struct {
    fin: bool,
    syn: bool,
    rst: bool,
    psh: bool,
    ack: bool,
    urg: bool,
    ece: bool,
    cwr: bool,
};

/// UDP Header (RFC 768) - Simplest!
pub const UDPHeader = packed struct {
    src_port: u16,
    dst_port: u16,
    length: u16,      // Header + Data length
    checksum: u16,

    pub const SIZE = 8;
};

// Verify struct sizes at compile time!
comptime {
    if (@sizeOf(IPv4Header) != 20) @compileError("IPv4Header must be 20 bytes");
    if (@sizeOf(TCPHeader) != 20) @compileError("TCPHeader must be 20 bytes");
    if (@sizeOf(UDPHeader) != 8) @compileError("UDPHeader must be 8 bytes");
}

// =============================================================================
//                    2. ENDIANNESS HANDLING
// =============================================================================
//
// CRITICAL untuk networking!
//
// Network byte order = Big Endian (MSB first)
// x86/x64 = Little Endian
// ARM = Configurable (usually Little Endian)
//
// SELALU convert saat:
// - Read dari network → convert to host order
// - Write ke network → convert to network order
// =============================================================================

/// Convert from network byte order (big-endian) to host byte order
pub fn ntoh(comptime T: type, value: T) T {
    return switch (native_endian) {
        .big => value,
        .little => @byteSwap(value),
    };
}

/// Convert from host byte order to network byte order (big-endian)
pub fn hton(comptime T: type, value: T) T {
    return ntoh(T, value); // Same operation!
}

pub fn endianDemo() void {
    // Example: Port 80 in different representations
    const port_host: u16 = 80;
    const port_network = hton(u16, port_host);

    std.debug.print("Port 80:\n", .{});
    std.debug.print("  Host order:    0x{X:0>4} (bytes: {X:0>2} {X:0>2})\n", .{
        port_host,
        @as(u8, @truncate(port_host >> 8)),
        @as(u8, @truncate(port_host)),
    });
    std.debug.print("  Network order: 0x{X:0>4} (bytes: {X:0>2} {X:0>2})\n", .{
        port_network,
        @as(u8, @truncate(port_network >> 8)),
        @as(u8, @truncate(port_network)),
    });

    // IP Address: 192.168.1.1
    const ip: u32 = (192 << 24) | (168 << 16) | (1 << 8) | 1;
    std.debug.print("\nIP 192.168.1.1: 0x{X:0>8}\n", .{ip});
}

// =============================================================================
//                    3. CASTING BYTES TO STRUCTS
// =============================================================================
//
// Pattern utama untuk parsing packets:
// 1. Receive raw bytes
// 2. Cast ke packed struct
// 3. Access fields by name
// =============================================================================

pub fn parseIPv4Packet(raw_bytes: []const u8) !*const IPv4Header {
    if (raw_bytes.len < @sizeOf(IPv4Header)) {
        return error.PacketTooShort;
    }

    // Cast bytes directly to struct pointer
    const header: *const IPv4Header = @ptrCast(@alignCast(raw_bytes.ptr));

    // Validate
    if (header.version != 4) {
        return error.InvalidIPVersion;
    }

    return header;
}

pub fn parseDemo() void {
    // Simulated raw IP packet (minimal valid header)
    const raw_packet = [_]u8{
        0x45,             // Version=4, IHL=5 (20 bytes)
        0x00,             // DSCP=0, ECN=0
        0x00, 0x3c,       // Total Length = 60
        0x1c, 0x46,       // Identification
        0x40, 0x00,       // Flags=Don't Fragment, Offset=0
        0x40,             // TTL = 64
        0x06,             // Protocol = TCP (6)
        0x00, 0x00,       // Checksum (not calculated)
        0xc0, 0xa8, 0x01, 0x01,  // Src: 192.168.1.1
        0xc0, 0xa8, 0x01, 0x02,  // Dst: 192.168.1.2
    };

    if (parseIPv4Packet(&raw_packet)) |header| {
        std.debug.print("\nParsed IPv4 Header:\n", .{});
        std.debug.print("  Version: {d}\n", .{header.version});
        std.debug.print("  Header Length: {d} bytes\n", .{header.getHeaderLength()});
        std.debug.print("  Total Length: {d}\n", .{ntoh(u16, header.total_length)});
        std.debug.print("  TTL: {d}\n", .{header.ttl});
        std.debug.print("  Protocol: {d}\n", .{header.protocol});

        // Parse IP addresses
        const src = ntoh(u32, header.src_addr);
        const dst = ntoh(u32, header.dst_addr);
        std.debug.print("  Source: {d}.{d}.{d}.{d}\n", .{
            @as(u8, @truncate(src >> 24)),
            @as(u8, @truncate(src >> 16)),
            @as(u8, @truncate(src >> 8)),
            @as(u8, @truncate(src)),
        });
        std.debug.print("  Dest: {d}.{d}.{d}.{d}\n", .{
            @as(u8, @truncate(dst >> 24)),
            @as(u8, @truncate(dst >> 16)),
            @as(u8, @truncate(dst >> 8)),
            @as(u8, @truncate(dst)),
        });
    } else |err| {
        std.debug.print("Parse error: {}\n", .{err});
    }
}

// =============================================================================
//                    4. CHECKSUMS (Internet Checksum)
// =============================================================================
//
// RFC 1071: One's complement sum of 16-bit words
// Used by IP, TCP, UDP, ICMP
// =============================================================================

pub fn internetChecksum(data: []const u8) u16 {
    var sum: u32 = 0;
    var i: usize = 0;

    // Sum 16-bit words
    while (i + 1 < data.len) : (i += 2) {
        const word: u16 = (@as(u16, data[i]) << 8) | data[i + 1];
        sum += word;
    }

    // Handle odd byte
    if (i < data.len) {
        sum += @as(u32, data[i]) << 8;
    }

    // Fold 32-bit sum to 16 bits
    while (sum >> 16 != 0) {
        sum = (sum & 0xFFFF) + (sum >> 16);
    }

    // One's complement
    return ~@as(u16, @truncate(sum));
}

// =============================================================================
//                    5. BUFFER MANAGEMENT
// =============================================================================
//
// Network programming = lots of buffers!
// - Receive buffers
// - Send buffers
// - Reassembly buffers (IP fragmentation)
// - Retransmission buffers (TCP)
//
// Zig patterns:
// - Fixed buffers untuk known sizes (MTU = 1500)
// - Arena allocator untuk packet lifetime
// - Ring buffers untuk queues
// =============================================================================

pub const PacketBuffer = struct {
    data: []u8,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) !PacketBuffer {
        const data = try allocator.alloc(u8, max_size);
        return .{
            .data = data,
            .len = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PacketBuffer) void {
        self.allocator.free(self.data);
    }

    pub fn getPayload(self: *PacketBuffer) []u8 {
        return self.data[0..self.len];
    }
};

/// Buffer pool untuk reuse tanpa allocation per-packet
pub fn BufferPool(comptime buffer_size: usize, comptime pool_size: usize) type {
    return struct {
        buffers: [pool_size][buffer_size]u8 = undefined,
        free_list: [pool_size]bool = [_]bool{true} ** pool_size,

        const Self = @This();

        pub fn acquire(self: *Self) ?[]u8 {
            for (&self.free_list, 0..) |*free, i| {
                if (free.*) {
                    free.* = false;
                    return &self.buffers[i];
                }
            }
            return null; // Pool exhausted
        }

        pub fn release(self: *Self, buf: []u8) void {
            const addr = @intFromPtr(buf.ptr);
            const base = @intFromPtr(&self.buffers[0]);
            const index = (addr - base) / buffer_size;
            if (index < pool_size) {
                self.free_list[index] = true;
            }
        }
    };
}

// MTU-sized buffer pool
const MTU = 1500;
const POOL_SIZE = 64;
var packet_pool: BufferPool(MTU, POOL_SIZE) = .{};

// =============================================================================
//                    6. STATE MACHINES (TCP States)
// =============================================================================
//
// TCP = Complex state machine!
// Zig enums + switch = perfect untuk state machines
// =============================================================================

pub const TCPState = enum {
    closed,
    listen,
    syn_sent,
    syn_received,
    established,
    fin_wait_1,
    fin_wait_2,
    close_wait,
    closing,
    last_ack,
    time_wait,

    pub fn canSendData(self: TCPState) bool {
        return self == .established or self == .close_wait;
    }

    pub fn canReceiveData(self: TCPState) bool {
        return self == .established or
               self == .fin_wait_1 or
               self == .fin_wait_2;
    }
};

pub const TCPEvent = enum {
    passive_open,    // Application: listen()
    active_open,     // Application: connect()
    send_syn,
    recv_syn,
    recv_syn_ack,
    recv_ack,
    send_fin,
    recv_fin,
    timeout,
    close,           // Application: close()
};

pub fn tcpTransition(state: TCPState, event: TCPEvent) ?TCPState {
    return switch (state) {
        .closed => switch (event) {
            .passive_open => .listen,
            .active_open => .syn_sent,
            else => null,
        },
        .listen => switch (event) {
            .recv_syn => .syn_received,
            .close => .closed,
            else => null,
        },
        .syn_sent => switch (event) {
            .recv_syn_ack => .established,
            .recv_syn => .syn_received,
            .close => .closed,
            .timeout => .closed,
            else => null,
        },
        .syn_received => switch (event) {
            .recv_ack => .established,
            .close => .fin_wait_1,
            else => null,
        },
        .established => switch (event) {
            .close => .fin_wait_1,
            .recv_fin => .close_wait,
            else => null,
        },
        .fin_wait_1 => switch (event) {
            .recv_ack => .fin_wait_2,
            .recv_fin => .closing,
            else => null,
        },
        .fin_wait_2 => switch (event) {
            .recv_fin => .time_wait,
            else => null,
        },
        .close_wait => switch (event) {
            .close => .last_ack,
            else => null,
        },
        .closing => switch (event) {
            .recv_ack => .time_wait,
            else => null,
        },
        .last_ack => switch (event) {
            .recv_ack => .closed,
            else => null,
        },
        .time_wait => switch (event) {
            .timeout => .closed,
            else => null,
        },
    };
}

// =============================================================================
//                    7. COMPTIME FOR PROTOCOL CONSTANTS
// =============================================================================
//
// Protocol numbers, well-known ports, dll bisa di-generate saat comptime
// =============================================================================

pub const Protocol = enum(u8) {
    icmp = 1,
    tcp = 6,
    udp = 17,
    _,

    pub fn fromNumber(n: u8) Protocol {
        return @enumFromInt(n);
    }
};

pub const WellKnownPorts = struct {
    pub const ftp_data = 20;
    pub const ftp_control = 21;
    pub const ssh = 22;
    pub const telnet = 23;
    pub const smtp = 25;
    pub const dns = 53;
    pub const http = 80;
    pub const pop3 = 110;
    pub const imap = 143;
    pub const https = 443;

    pub fn isPrivileged(port: u16) bool {
        return port < 1024;
    }

    pub fn isEphemeral(port: u16) bool {
        return port >= 49152;
    }
};

// =============================================================================
//                    8. ERROR HANDLING FOR NETWORK
// =============================================================================
//
// Network errors berbeda dari typical errors:
// - Transient (bisa retry)
// - Permanent (jangan retry)
// - Timeout-based
// =============================================================================

pub const NetworkError = error{
    // Transient - bisa retry
    WouldBlock,
    Interrupted,
    ConnectionReset,

    // Permanent
    ConnectionRefused,
    NetworkUnreachable,
    HostUnreachable,
    AddressInUse,
    AddressNotAvailable,

    // Protocol errors
    InvalidPacket,
    ChecksumMismatch,
    PacketTooShort,
    InvalidIPVersion,

    // Resource errors
    OutOfBuffers,
    OutOfMemory,
};

pub fn isRetryable(err: NetworkError) bool {
    return switch (err) {
        .WouldBlock, .Interrupted, .ConnectionReset => true,
        else => false,
    };
}

// =============================================================================
//                    9. TIMING & TIMEOUTS
// =============================================================================
//
// Network programming butuh precise timing untuk:
// - Retransmission timers (TCP)
// - Keep-alive timers
// - Connection timeouts
// - RTT measurement
// =============================================================================

pub const Timer = struct {
    start_time: i64,
    timeout_ns: i64,

    pub fn start(timeout_ms: u64) Timer {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .timeout_ns = @intCast(timeout_ms * std.time.ns_per_ms),
        };
    }

    pub fn hasExpired(self: Timer) bool {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        return elapsed >= self.timeout_ns;
    }

    pub fn remaining(self: Timer) u64 {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        if (elapsed >= self.timeout_ns) return 0;
        return @intCast((self.timeout_ns - elapsed) / std.time.ns_per_ms);
    }
};

/// RTT estimator (Jacobson's algorithm) untuk TCP
pub const RTTEstimator = struct {
    srtt: i64 = 0,      // Smoothed RTT
    rttvar: i64 = 0,    // RTT variance
    rto: i64 = 1000,    // Retransmission timeout (ms)

    const ALPHA = 8;    // 1/8 untuk SRTT smoothing
    const BETA = 4;     // 1/4 untuk RTTVAR smoothing

    pub fn update(self: *RTTEstimator, measured_rtt: i64) void {
        if (self.srtt == 0) {
            // First measurement
            self.srtt = measured_rtt;
            self.rttvar = measured_rtt / 2;
        } else {
            // Jacobson's algorithm
            const delta = measured_rtt - self.srtt;
            self.srtt += delta / ALPHA;

            const abs_delta = if (delta < 0) -delta else delta;
            self.rttvar += (abs_delta - self.rttvar) / BETA;
        }

        // RTO = SRTT + 4 * RTTVAR
        self.rto = self.srtt + 4 * self.rttvar;

        // Clamp RTO
        if (self.rto < 200) self.rto = 200;    // Min 200ms
        if (self.rto > 60000) self.rto = 60000; // Max 60s
    }
};

// =============================================================================
//                    SUMMARY: Zig Features untuk TCP/IP
// =============================================================================
//
//    ┌────────────────────┬────────────────────────────────────────────────┐
//    │  Feature           │  Use Case                                      │
//    ├────────────────────┼────────────────────────────────────────────────┤
//    │  packed struct     │  Protocol headers (IP, TCP, UDP)               │
//    │  @byteSwap         │  Endianness conversion                         │
//    │  @ptrCast          │  Cast bytes to struct                          │
//    │  comptime          │  Protocol constants, lookup tables             │
//    │  enum + switch     │  State machines (TCP states)                   │
//    │  error union       │  Network error handling                        │
//    │  slices []u8       │  Packet data, payloads                         │
//    │  Arena allocator   │  Per-connection memory                         │
//    │  Fixed buffers     │  MTU-sized packet buffers                      │
//    │  Bit fields        │  Protocol flags, header fields                 │
//    └────────────────────┴────────────────────────────────────────────────┘
//
// =============================================================================

pub fn main() void {
    std.debug.print("=== Zig for Networking Demo ===\n\n", .{});

    endianDemo();
    parseDemo();

    std.debug.print("\n--- Checksum Demo ---\n", .{});
    const test_data = [_]u8{ 0x00, 0x01, 0xf2, 0x03, 0xf4, 0xf5, 0xf6, 0xf7 };
    const checksum = internetChecksum(&test_data);
    std.debug.print("Checksum: 0x{X:0>4}\n", .{checksum});

    std.debug.print("\n--- TCP State Machine ---\n", .{});
    var state = TCPState.closed;
    std.debug.print("Initial: {}\n", .{state});

    if (tcpTransition(state, .passive_open)) |new_state| {
        state = new_state;
        std.debug.print("After passive_open: {}\n", .{state});
    }

    if (tcpTransition(state, .recv_syn)) |new_state| {
        state = new_state;
        std.debug.print("After recv_syn: {}\n", .{state});
    }
}

test "packed struct sizes" {
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(IPv4Header));
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(TCPHeader));
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(UDPHeader));
}

test "endianness" {
    const value: u16 = 0x1234;
    const swapped = hton(u16, value);
    const back = ntoh(u16, swapped);
    try std.testing.expectEqual(value, back);
}
