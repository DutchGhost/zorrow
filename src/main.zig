fn Borrow(comptime T: type, comptime borrows: *usize) type {
    comptime var alive = true;

    return struct {
        pointer: *const T,

        pub fn read(self: *const @This(), comptime uniq: type) T {
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

        pub fn write(self: *@This(), value: T, comptime uniq: type) void {
            if (!alive)
                @compileError("BorrowMut no longer alive!");

            self.pointer.* = value;
        }

        pub fn read(self: *const @This(), comptime uniq: type) T {
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

pub fn RefCell(comptime T: type) type {
    comptime var borrows: usize = 0;
    comptime var mutborrows: usize = 0;

    return struct {
        value: T,

        pub fn init(value: T) @This() {
            return @This(){ .value = value };
        }

        pub fn borrow(self: *const @This(), comptime uniq: type) Borrow(T, &borrows) {
            comptime if (mutborrows > 0)
                @compileError("There is a mutable borrow active!");

            borrows += 1;

            return .{ .pointer = &self.value };
        }

        pub fn borrowMut(self: *@This(), comptime uniq: type) BorrowMut(T, &mutborrows) {
            comptime if (borrows > 0 or mutborrows > 0)
                @compileError("There is a borrow[mut] active!");

            mutborrows += 1;

            return .{.pointer = &self.value };
        }
    };
}

const testing = @import("std").testing;

test "borrowck" {
    var cell = RefCell(usize).init(10);
    var b0 = cell.borrow(struct {});
    var b1 = cell.borrow(struct {});

    testing.expectEqual(b0.read(struct {}), 10);
    testing.expectEqual(b1.read(struct {}), 10);


    b0.release();
    // b1.read(); // <--- FAILS: read after release
    _ = b1.read(struct {});
    _ = b1.read(struct {});
    b1.release();

    var bm1 = cell.borrowMut(struct {});
    // var b2 = cell.borrow(struct {}); // <--- FAILS: borrow while mut borrow is active
    // var bm2 = cell.borrowMut(struct {}); // <--- FAILS borrowmut while mut borrow is active
    bm1.write(11, struct {});
    testing.expectEqual(bm1.read(struct {}), 11);
    bm1.release();
    // bm1.write(20); // <--- FAILS: write after release
}

test "defer release" {
    var cell = RefCell(usize).init(20);
    {
        var borrow = cell.borrow(struct {});
        defer borrow.release();

        testing.expectEqual(borrow.read(struct {}), 20);
    }
    {
        var mutborrow = cell.borrowMut(struct {});
        defer mutborrow.release();
        testing.expectEqual(mutborrow.read(struct {}), 20);

        mutborrow.write(0, struct {});
        testing.expectEqual(mutborrow.read(struct {}), 0);
    }
}