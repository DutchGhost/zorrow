fn Borrow(comptime T: type, comptime borrows: *usize) type {
    comptime var alive = true;

    return struct {
        pointer: *const T,

        pub fn read(self: *const @This(), comptime uniq: var) T {
            if (!alive)
                @compileError("Borrow no longer alive!");

            return self.pointer.*;
        }

        pub fn release(self: @This()) void {
            alive = false;
            borrows.* -= 1;
        }
    };
}

fn BorrowMut(comptime T: type, comptime borrowmuts: *usize) type {
    comptime var alive: bool = true;

    return struct {
        pointer: *T,

        pub fn write(self: *@This(), value: T, comptime uniq: var) void {
            if (!alive)
                @compileError("BorrowMut no longer alive!");

            self.pointer.* = value;
        }

        pub fn read(self: *const @This(), comptime uniq: var) T {
            if (!alive)
                @compileError("BorrowMut no longer alive!");

            return self.pointer.*;
        }

        pub fn release(self: @This()) void {
            alive = false;
            borrowmuts.* -= 1;
        }
    };
}

/// A borrowable memory location.
/// Borrows are checked at compiletime. It works just like
/// a read-write lock; There may be many borrows at a time,
/// *or* only one mutable borrow at a time.
pub fn RefCell(comptime T: type) type {
    comptime var borrows: usize = 0;
    comptime var mutborrows: usize = 0;

    return struct {
        value: T,

        pub fn init(value: T) @This() {
            return @This(){ .value = value };
        }

        /// Borrows the value. As long as a `borrow` is alive, there may not be
        /// any mutable borrow alive. Borrows can be released by calling `.release()`.
        pub fn borrow(self: *const @This(), comptime uniq: var) Borrow(T, &borrows) {
            comptime if (mutborrows > 0)
                @compileError("There is a mutable borrow active!");

            borrows += 1;

            return .{ .pointer = &self.value };
        }

        /// Borrows the value mutably. As long as `mut borrow` is alive, there may not be
        /// any other borrow or mutable borrow alive. In order words, a live mutable borrow
        /// is a unique borrow.
        pub fn borrowMut(self: *@This(), comptime uniq: var) BorrowMut(T, &mutborrows) {
            comptime if (borrows > 0 or mutborrows > 0)
                @compileError("There is a borrow[mut] active!");

            mutborrows += 1;

            return .{ .pointer = &self.value };
        }
    };
}

const testing = @import("std").testing;

test "borrowck" {
    var cell = RefCell(usize).init(10);
    var b0 = cell.borrow(.{});
    var b1 = cell.borrow(.{});

    testing.expectEqual(b0.read(.{}), 10);
    testing.expectEqual(b1.read(.{}), 10);

    b0.release();
    // _ = b0.read(.{}); // <--- FAILS: read after release
    _ = b1.read(.{});
    _ = b1.read(.{});
    b1.release();

    var bm1 = cell.borrowMut(.{});
    // var b2 = cell.borrow(.{}); // <--- FAILS: borrow while mut borrow is active
    // var bm2 = cell.borrowMut(.{}); // <--- FAILS borrowmut while mut borrow is active
    bm1.write(11, .{});
    testing.expectEqual(bm1.read(.{}), 11);
    bm1.release();
    // bm1.write(20, .{}); // <--- FAILS: write after release
}

test "defer release" {
    var cell = RefCell(usize).init(20);
    {
        var borrow = cell.borrow(.{});
        defer borrow.release();

        testing.expectEqual(borrow.read(.{}), 20);
    }
    {
        var mutborrow = cell.borrowMut(.{});
        defer mutborrow.release();

        testing.expectEqual(mutborrow.read(.{}), 20);

        mutborrow.write(0, .{});
        testing.expectEqual(mutborrow.read(.{}), 0);
    }
}
