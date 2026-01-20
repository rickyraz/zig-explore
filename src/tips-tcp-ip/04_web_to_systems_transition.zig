// =============================================================================
//              WEB ENGINEER → SYSTEMS ENGINEER TRANSITION
//                  Tips untuk TCP/IP Implementation
// =============================================================================
//
// Guide untuk web developer (JS/TS/Python background) yang mau
// implement TCP/IP stack dari scratch.
//
// =============================================================================

const std = @import("std");

// =============================================================================
//                    MINDSET SHIFT
// =============================================================================
//
//    ┌────────────────────────────────────────────────────────────────────────┐
//    │                    WEB vs SYSTEMS MINDSET                              │
//    │                                                                        │
//    │   WEB WORLD                          SYSTEMS WORLD                     │
//    │   ──────────                         ─────────────                     │
//    │                                                                        │
//    │   "It works!" ──────────────────────▶ "It works CORRECTLY"            │
//    │                                       under all conditions             │
//    │                                                                        │
//    │   Garbage collector ────────────────▶ YOU manage memory               │
//    │   handles memory                      Every byte matters              │
//    │                                                                        │
//    │   Exceptions fly ───────────────────▶ Handle EVERY error              │
//    │   up the stack                        or crash gracefully             │
//    │                                                                        │
//    │   "Let it crash" ───────────────────▶ Crashes = data loss             │
//    │   restart process                     or security vuln                │
//    │                                                                        │
//    │   String is string ─────────────────▶ String = bytes + encoding       │
//    │                                       UTF-8? ASCII? Binary?           │
//    │                                                                        │
//    │   JSON everywhere ──────────────────▶ Binary protocols                │
//    │                                       Bit-level precision             │
//    │                                                                        │
//    │   Latency ~100ms OK ────────────────▶ Microseconds matter             │
//    │                                                                        │
//    │   Memory is infinite ───────────────▶ Every allocation                │
//    │                                       has cost                         │
//    │                                                                        │
//    │   "npm install" ────────────────────▶ Understand every                │
//    │   magic library                       line of code                     │
//    │                                                                        │
//    └────────────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    CONCEPT MAPPING: Web → Systems
// =============================================================================
//
//    ┌──────────────────────┬───────────────────────────────────────────────┐
//    │  Web Concept         │  Systems Equivalent                           │
//    ├──────────────────────┼───────────────────────────────────────────────┤
//    │  HTTP Request        │  TCP segment + IP packet + Ethernet frame    │
//    │  JSON payload        │  Binary data with exact byte layout          │
//    │  fetch() / axios     │  socket() + connect() + send() + recv()      │
//    │  WebSocket           │  TCP connection with custom protocol         │
//    │  REST API            │  Application protocol on TCP                  │
//    │  DNS lookup          │  UDP packet to DNS server                     │
//    │  "Connection"        │  TCP 3-way handshake + state machine         │
//    │  Timeout             │  Timer + retransmission                       │
//    │  Load balancer       │  Routing table + interface selection         │
//    │  Buffer (Node.js)    │  Raw byte array with explicit length         │
//    │  Promise/async       │  Event loop / poll / select / epoll          │
//    │  Streams             │  Ring buffer + flow control                   │
//    └──────────────────────┴───────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    1. BINARY DATA HANDLING
// =============================================================================
//
// Di web: JSON.parse(text), selesai.
// Di systems: Setiap BYTE dan BIT punya makna!
//
// =============================================================================

pub const BinaryLesson = struct {

    // WEB MINDSET:
    // const data = { port: 80, flags: ["SYN", "ACK"] };
    // const json = JSON.stringify(data);
    // fetch(url, { body: json });

    // SYSTEMS MINDSET:
    // Port 80 = 2 bytes, big-endian
    // Flags = specific bits in a byte

    pub fn webVsSystemsDemo() void {
        // Web: "port 80" is just a number
        // Systems: port 80 = 0x0050 in network byte order

        const port: u16 = 80;

        // On little-endian machine (x86):
        // Memory layout: 0x50, 0x00

        // Network byte order (big-endian):
        // Wire layout: 0x00, 0x50

        const network_port = std.mem.nativeToBig(u16, port);
        std.debug.print("Port {d}:\n", .{port});
        std.debug.print("  Host byte order:    0x{X:0>4}\n", .{port});
        std.debug.print("  Network byte order: 0x{X:0>4}\n", .{network_port});

        // Flags: Not an array of strings!
        // TCP flags = 1 byte, each bit is a flag
        //
        // Bit 0: FIN
        // Bit 1: SYN
        // Bit 2: RST
        // Bit 3: PSH
        // Bit 4: ACK
        // Bit 5: URG
        //
        // SYN+ACK = 0b00010010 = 0x12

        const Flags = packed struct {
            fin: bool,
            syn: bool,
            rst: bool,
            psh: bool,
            ack: bool,
            urg: bool,
            _padding: u2 = 0,
        };

        const syn_ack = Flags{
            .fin = false,
            .syn = true,
            .rst = false,
            .psh = false,
            .ack = true,
            .urg = false,
        };

        const as_byte: u8 = @bitCast(syn_ack);
        std.debug.print("\nSYN+ACK flags: 0x{X:0>2} (binary: {b:0>8})\n", .{ as_byte, as_byte });
    }

    // TIP: Selalu visualisasi byte layout!
    //
    // TCP Header (20 bytes minimum):
    // Offset  0                   1                   2                   3
    // Octet   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    //        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    //      0 |          Source Port          |       Destination Port        |
    //        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    //      4 |                        Sequence Number                        |
    //        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    //      8 |                    Acknowledgment Number                      |
    //        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    //     12 |  Data |     |N|C|E|U|A|P|R|S|F|                               |
    //        | Offset| Res |S|W|C|R|C|S|S|Y|I|            Window             |
    //        |       |     | |R|E|G|K|H|T|N|N|                               |
    //        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    //     16 |           Checksum            |         Urgent Pointer        |
    //        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    //     20 |                    Options (if Data Offset > 5)               |
    //        +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
};

// =============================================================================
//                    2. MEMORY MANAGEMENT
// =============================================================================
//
// Di web: Let garbage collector handle it
// Di systems: YOU are responsible for EVERY BYTE
//
// =============================================================================

pub const MemoryLesson = struct {

    // WEB MINDSET:
    // function processPacket(data) {
    //     const copy = [...data];  // GC handles old array
    //     const result = transform(copy);
    //     return result;  // GC handles copy when unused
    // }
    //
    // SYSTEMS MINDSET:
    // - Where does memory come from?
    // - When is it freed?
    // - What if allocation fails?
    // - Can I reuse instead of allocate?

    // Pattern 1: Stack allocation (fastest, automatic cleanup)
    pub fn stackAllocation() void {
        // local variable is never mutatedzls
        // var buffer: [1500]u8 = undefined; // On stack, MTU-sized

        const buffer: [1500]u8 = undefined; // On stack, MTU-sized
        // No allocation, no free needed
        // Automatically "freed" when function returns
        _ = buffer;
    }

    // Pattern 2: Pre-allocated pools (no runtime allocation)
    pub fn BufferPool(comptime size: usize, comptime count: usize) type {
        return struct {
            buffers: [count][size]u8 = undefined,
            in_use: [count]bool = [_]bool{false} ** count,

            pub fn acquire(self: *@This()) ?*[size]u8 {
                for (&self.in_use, 0..) |*used, i| {
                    if (!used.*) {
                        used.* = true;
                        return &self.buffers[i];
                    }
                }
                return null; // Pool exhausted
            }

            pub fn release(self: *@This(), buf: *[size]u8) void {
                const index = (@intFromPtr(buf) - @intFromPtr(&self.buffers)) / size;
                self.in_use[index] = false;
            }
        };
    }

    // Pattern 3: Arena untuk short-lived allocations
    pub fn arenaPattern(allocator: std.mem.Allocator) !void {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit(); // Free EVERYTHING at once

        // Allocate freely within arena
        const buf1 = try arena.allocator().alloc(u8, 100);
        const buf2 = try arena.allocator().alloc(u8, 200);
        // Process packet...
        _ = buf1;
        _ = buf2;

        // No individual free needed!
        // arena.deinit() frees all at once
    }

    // TIP: Think about memory LIFETIME
    //
    // ┌─────────────────────────────────────────────────────────────────┐
    // │  Lifetime        │  Allocation Strategy                        │
    // ├─────────────────────────────────────────────────────────────────┤
    // │  Function call   │  Stack (var buffer: [N]u8)                  │
    // │  Single packet   │  Arena or pool                              │
    // │  TCP connection  │  Per-connection allocator                   │
    // │  Program lifetime│  Static / global                            │
    // └─────────────────────────────────────────────────────────────────┘
};

// =============================================================================
//                    3. ERROR HANDLING
// =============================================================================
//
// Di web: try/catch, let it bubble up
// Di systems: Every error is a decision point
//
// =============================================================================

pub const ErrorLesson = struct {

    // WEB MINDSET:
    // async function sendPacket(data) {
    //     const response = await fetch(url, data);
    //     return response.json();  // Just throw on error
    // }
    //
    // SYSTEMS MINDSET:
    // - What if network is down?
    // - What if buffer is full?
    // - What if checksum fails?
    // - Should we retry? Drop? Log?

    pub const NetworkError = error{
        // Transient - mungkin bisa retry
        WouldBlock,
        Interrupted,
        TimedOut,
        ConnectionReset,

        // Permanent - jangan retry
        ConnectionRefused,
        NetworkUnreachable,
        InvalidPacket,
        ChecksumFailed,
        OutOfMemory,
    };

    pub fn shouldRetry(err: NetworkError) bool {
        return switch (err) {
            .WouldBlock, .Interrupted, .TimedOut, .ConnectionReset => true,
            else => false,
        };
    }

    // Pattern: Explicit error handling at EVERY layer
    pub fn sendWithRetry(data: []const u8, max_retries: u32) NetworkError!void {
        var attempts: u32 = 0;
        while (attempts < max_retries) : (attempts += 1) {
            sendPacket(data) catch |err| {
                if (shouldRetry(err) and attempts + 1 < max_retries) {
                    // Log, maybe exponential backoff
                    continue;
                }
                return err;
            };
            return; // Success
        }
        return NetworkError.TimedOut;
    }

    fn sendPacket(data: []const u8) NetworkError!void {
        _ = data;
        // Actual send logic
    }
};

// =============================================================================
//                    4. CONCURRENCY
// =============================================================================
//
// Di web: async/await, event loop handled by runtime
// Di systems: YOU build the event loop
//
// =============================================================================

pub const ConcurrencyLesson = struct {

    // WEB MINDSET (Node.js):
    // server.on('data', (packet) => {
    //     process(packet);  // Event loop magic!
    // });
    //
    // SYSTEMS MINDSET:
    // - poll() / select() / epoll() / kqueue()
    // - Manually check which sockets are ready
    // - Non-blocking I/O

    // Simplified event loop structure
    pub const EventLoop = struct {
        // File descriptors we're watching
        sockets: std.ArrayList(i32),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) EventLoop {
            return .{
                .sockets = std.ArrayList(i32).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn addSocket(self: *EventLoop, fd: i32) !void {
            try self.sockets.append(fd);
        }

        // Main loop pattern
        pub fn run(self: *EventLoop) !void {
            while (true) {
                // 1. Wait for events (poll/epoll/kqueue)
                const ready = try self.waitForEvents();

                // 2. Process each ready socket
                for (ready) |fd| {
                    try self.handleSocket(fd);
                }

                // 3. Process timers
                try self.processTimers();
            }
        }

        fn waitForEvents(self: *EventLoop) ![]i32 {
            // Real implementation would use poll/epoll/kqueue
            _ = self;
            return &[_]i32{};
        }

        fn handleSocket(self: *EventLoop, fd: i32) !void {
            _ = self;
            _ = fd;
            // Read data, process packet
        }

        fn processTimers(self: *EventLoop) !void {
            _ = self;
            // Check for expired timers (TCP retransmit, etc)
        }
    };
};

// =============================================================================
//                    5. DEBUGGING TIPS
// =============================================================================
//
// Di web: console.log(), browser devtools
// Di systems: Wireshark, hexdump, printf debugging
//
// =============================================================================

pub const DebuggingLesson = struct {

    // Essential tools:
    // 1. Wireshark - capture dan analyze packets
    // 2. tcpdump - CLI packet capture
    // 3. hexdump - view binary data
    // 4. strace - trace system calls

    // Helper: Print packet as hex dump
    pub fn hexDump(data: []const u8) void {
        var i: usize = 0;
        while (i < data.len) {
            // Offset
            std.debug.print("{X:0>4}: ", .{i});

            // Hex bytes
            var j: usize = 0;
            while (j < 16 and i + j < data.len) : (j += 1) {
                std.debug.print("{X:0>2} ", .{data[i + j]});
            }

            // Padding
            while (j < 16) : (j += 1) {
                std.debug.print("   ", .{});
            }

            // ASCII
            std.debug.print(" |", .{});
            j = 0;
            while (j < 16 and i + j < data.len) : (j += 1) {
                const c = data[i + j];
                if (c >= 0x20 and c < 0x7F) {
                    std.debug.print("{c}", .{c});
                } else {
                    std.debug.print(".", .{});
                }
            }
            std.debug.print("|\n", .{});

            i += 16;
        }
    }

    // Helper: Print IP address
    pub fn printIP(ip: u32) void {
        std.debug.print("{d}.{d}.{d}.{d}", .{
            @as(u8, @truncate(ip >> 24)),
            @as(u8, @truncate(ip >> 16)),
            @as(u8, @truncate(ip >> 8)),
            @as(u8, @truncate(ip)),
        });
    }

    // DEBUGGING CHECKLIST for network issues:
    //
    // □ Checksum correct?
    // □ Byte order correct (big-endian on wire)?
    // □ Header length correct?
    // □ Packet length matches actual data?
    // □ Compare with Wireshark capture of working implementation
    // □ State machine in correct state?
    // □ Sequence numbers wrapping correctly?
};

// =============================================================================
//                    6. TESTING STRATEGY
// =============================================================================
//
// Di web: Jest, Mocha, mock everything
// Di systems: Unit test + integration with real packets
//
// =============================================================================

pub const TestingLesson = struct {

    // 1. UNIT TESTS - Test individual functions
    //    - Checksum calculation
    //    - Header parsing
    //    - State machine transitions

    // 2. LOOPBACK TESTS - Talk to yourself
    //    - Send packet to 127.0.0.1
    //    - Verify you receive it correctly

    // 3. INTEGRATION TESTS - Talk to real stack
    //    - Your UDP client → Linux UDP server
    //    - Linux TCP client → Your TCP server

    // 4. CONFORMANCE TESTS - RFC compliance
    //    - Edge cases from RFCs
    //    - Malformed packets
    //    - Stress tests

    // 5. CAPTURE REPLAY - Use Wireshark captures
    //    - Record working session
    //    - Replay packets to your implementation
    //    - Compare responses
};

// =============================================================================
//                    7. INCREMENTAL DEVELOPMENT APPROACH
// =============================================================================
//
//    RECOMMENDED ORDER:
//
//    Phase 1: Foundation
//    ┌────────────────────────────────────────────────────────────────┐
//    │  1. Implement packed structs untuk semua headers               │
//    │  2. Implement checksum calculation                             │
//    │  3. Implement byte order conversion helpers                    │
//    │  4. Test dengan comparing to Wireshark                         │
//    └────────────────────────────────────────────────────────────────┘
//
//    Phase 2: UDP (Simpler protocol)
//    ┌────────────────────────────────────────────────────────────────┐
//    │  1. UDP header parsing/creation                                │
//    │  2. Socket binding                                             │
//    │  3. Send/receive datagrams                                     │
//    │  4. Test: DNS query (UDP port 53)                              │
//    └────────────────────────────────────────────────────────────────┘
//
//    Phase 3: IP Layer
//    ┌────────────────────────────────────────────────────────────────┐
//    │  1. IP header parsing/creation                                 │
//    │  2. Routing (simple: default gateway)                          │
//    │  3. Fragment reassembly                                        │
//    │  4. Test: ICMP ping                                            │
//    └────────────────────────────────────────────────────────────────┘
//
//    Phase 4: TCP (Complex!)
//    ┌────────────────────────────────────────────────────────────────┐
//    │  1. TCP header parsing/creation                                │
//    │  2. State machine (start with LISTEN → ESTABLISHED only)       │
//    │  3. 3-way handshake                                            │
//    │  4. Simple data transfer (no flow control)                     │
//    │  5. Connection close                                           │
//    │  6. Add sliding window                                         │
//    │  7. Add retransmission                                         │
//    │  8. Add congestion control                                     │
//    │  9. Test: HTTP GET request                                     │
//    └────────────────────────────────────────────────────────────────┘
//
// =============================================================================

// =============================================================================
//                    8. RESOURCES
// =============================================================================
//
//    BOOKS:
//    - TCP/IP Illustrated Vol 1: The Protocols (MUST READ)
//    - TCP/IP Illustrated Vol 2: The Implementation
//    - Unix Network Programming Vol 1 (Stevens)
//
//    RFCs (Primary Sources):
//    - RFC 791: IP
//    - RFC 792: ICMP
//    - RFC 768: UDP
//    - RFC 793: TCP
//    - RFC 1122: Host Requirements
//    - RFC 5681: TCP Congestion Control
//    - RFC 6298: Computing TCP's Retransmission Timer
//
//    TOOLS:
//    - Wireshark (essential!)
//    - tcpdump
//    - netcat (nc)
//    - iperf3 (performance testing)
//
//    EXISTING IMPLEMENTATIONS (Reference):
//    - Linux kernel (net/ipv4/)
//    - FreeBSD (sys/netinet/)
//    - lwIP (lightweight, good for learning)
//    - smoltcp (Rust, modern)
//
// =============================================================================

pub fn main() void {
    std.debug.print("=== Web to Systems Transition Guide ===\n\n", .{});

    std.debug.print("--- Binary Data Handling ---\n", .{});
    BinaryLesson.webVsSystemsDemo();

    std.debug.print("\n--- Hex Dump Demo ---\n", .{});
    const sample_packet = [_]u8{
        0x45, 0x00, 0x00, 0x3c, // IP: Version, IHL, TOS, Total Length
        0x1c, 0x46, 0x40, 0x00, // IP: ID, Flags, Fragment Offset
        0x40, 0x06, 0x00, 0x00, // IP: TTL, Protocol (TCP), Checksum
        0xc0, 0xa8, 0x01, 0x01, // IP: Source (192.168.1.1)
        0xc0, 0xa8, 0x01, 0x02, // IP: Dest (192.168.1.2)
    };
    DebuggingLesson.hexDump(&sample_packet);
}
