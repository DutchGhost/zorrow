const testing = @import("std").testing;

fn Borrow(comptime T: type, comptime borrows: *usize) type {
    comptime var alive = true;

    return struct {
        pointer: *const T,
        const Self = @This();
        pub fn read(self: *const Self, comptime uniq: anytype) T {
            _ = uniq;
            if (!alive)
                @compileError("Borrow no longer alive!");

            return self.pointer.*;
        }

        pub fn release(self: Self) void {
            _ = self;
            alive = false;
            borrows.* -= 1;
        }
    };
}

fn BorrowMut(comptime T: type, comptime borrowmuts: ?*usize) type {
    _ = borrowmuts;
    comptime var alive: bool = true;

    return struct {
        pointer: *T,

        const Self = @This();

        pub fn write(self: *Self, value: T, comptime uniq: anytype) void {
            _ = uniq;
            if (!alive)
                @compileError("BorrowMut no longer alive!");

            self.pointer.* = value;
        }

        pub fn read(self: *const Self, comptime uniq: anytype) T {
            _ = uniq;
            if (!alive)
                @compileError("BorrowMut no longer alive!");

            return self.pointer.*;
        }

        pub fn release(self: Self) void {
            _ = self;
            alive = false;
            // borrowmuts.?.* -= 1;
        }
    };
}

/// A borrowable memory location.
/// Borrows are checked at compiletime. It works just like
/// a read-write lock; There may be many borrows at a time,
/// *or* only one mutable borrow at a time.
pub fn RefCell(comptime T: type, comptime _: anytype) type {
    comptime var borrows: usize = 0;
    comptime var mutborrows: usize = 0;

    return struct {
        value: T,

        const Self = @This();
        pub fn init(value: T) Self {
            return Self{ .value = value };
        }

        /// Borrows the value. As long as a `borrow` is alive, there may not be
        /// any mutable borrow alive. Borrows can be released by calling `.release()`.
        pub fn borrow(self: *const Self, comptime uniq: anytype) Borrow(T, &borrows) {
            _ = uniq;
            comptime if (borrows > 0 and mutborrows > 0) {
                @compileError("Value has already been unwrapped!");
            } else if (mutborrows > 0) {
                @compileError("There is a mutable borrow active!");
            };

            borrows += 1;

            return .{ .pointer = &self.value };
        }

        /// Borrows the value mutably. As long as `mut borrow` is alive, there may not be
        /// any other borrow or mutable borrow alive. In order words, a live mutable borrow
        /// is a unique borrow.
        pub fn borrowMut(self: *Self, comptime uniq: anytype) BorrowMut(T, &mutborrows) {
            _ = uniq;
            comptime if (borrows > 0 and mutborrows > 0) {
                @compileError("Value has already been unwrapped!");
            } else if (borrows > 0 or mutborrows > 0) {
                @compileError("There is a borrow[mut] active!");
            };

            mutborrows += 1;

            return .{ .pointer = &self.value };
        }

        pub fn unwrap(self: *Self, comptime uniq: anytype) T {
            _ = uniq;
            comptime if (borrows > 0 and mutborrows > 0) {
                @compileError("Value has already been unwrapped!");
            } else if (borrows > 0 or mutborrows > 0) {
                @compileError("There is an  borrow[mut] active!");
            };

            mutborrows += 1;
            borrows += 1;
            return self.value;
        }
    };
}

test "unwrap" {
    var cell = RefCell(usize, opaque {}).init(10);
    var cell2 = RefCell(usize, opaque {}).init(10);

    try testing.expectEqual(cell.unwrap(opaque {}), cell2.unwrap(opaque {}));
    //_ = cell.unwrap(opaque {}); // <--- FAILS: already unwrapped
    //_ = cell.borrow(opaque {}); // <--- FAILS: already unwrapped
    //_ = cell.borrowMut(opaque {}); // <--- FAILS: already unwrapped
}

test "borrowck" {
    var cell = RefCell(usize, opaque {}).init(10);
    var b0 = cell.borrow(opaque {});
    var b1 = cell.borrow(opaque {});

    try testing.expectEqual(b0.read(opaque {}), 10);
    try testing.expectEqual(b1.read(opaque {}), 10);

    b0.release();
    // _ = b0.read(opaque {}); // <--- FAILS: read after release
    _ = b1.read(opaque {});
    _ = b1.read(opaque {});
    b1.release();

    var bm1 = cell.borrowMut(opaque {});
    // var b2 = cell.borrow(opaque {}); // <--- FAILS: borrow while mut borrow is active
    // var bm2 = cell.borrowMut(opaque {}); // <--- FAILS borrowmut while mut borrow is active
    bm1.write(11, opaque {});
    try testing.expectEqual(bm1.read(opaque {}), 11);
    bm1.release();
    // bm1.write(20, opaque {}); // <--- FAILS: write after release
}

test "defer release" {
    var cell = RefCell(usize, opaque {}).init(20);
    {
        var borrow = cell.borrow(opaque {});
        defer borrow.release();

        try testing.expectEqual(borrow.read(opaque {}), 20);
    }
    // fixme: Borrow no longer alive!
    // {
    //     var mutborrow = cell.borrowMut(opaque {});
    //     defer mutborrow.release();

    //     try testing.expectEqual(mutborrow.read(opaque {}), 20);

    //     mutborrow.write(0, opaque {});
    //     try testing.expectEqual(mutborrow.read(opaque {}), 0);
    // }
}

test "Rcursively references all the declarations" {
    testing.refAllDeclsRecursive(@This());
}
