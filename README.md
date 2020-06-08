# Zorrow
This is a userlevel implementation of borrowchk in Zig.

This system is *not* borrowchk, as it requires to pass in unique types for operations like acquiring a borrow, and reading from it. This library does not check for uniqueness of the types passed in, it's up to the programmer to do this correctly. An example of what is ment by `unique type`:

```Zig
var cell = RefCell(usize).init(10);

var borrow = cell.borrow(struct {});
defer borrow.release();

var value = borrow.read(struct {});
```
Here we see `struct {}` two times. it is required to pass those in.

## Minimum supported `Zig`
`master`

## Recent changes
  * 0.1
    * Initial implementation