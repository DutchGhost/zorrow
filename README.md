# Zorrow
This is a userlevel implementation of borrowchk in Zig.

This system is *not* borrowchk, as it requires to pass in unique types for operations
like acquiring a borrow, and reading from it. This library does not check for uniqueness
of the types passed in, it's up to the programmer to do this correctly.
An example of what is ment by `unique type`:

```Zig
var cell = RefCell(usize, opaque {}).init(10);

var borrow = cell.borrow(opaque {});
defer borrow.release();

var value = borrow.read(opaque {});
```
Here we see `opaque {}` three times. it is required to pass those in, as Zorrow
heavily relies on unique types passed into it's API.

## Minimum supported `Zig`
`master`

## Recent changes
  * 0.2.1
    * Change all occurrences of `var` as argument type to `anytype`.
  * 0.2
    * Allow the use of `.{}` where previously `struct {}` was required.
  * 0.1
    * Initial implementation

## Contributors
  * [suirad](https://github.com/suirad)
  * [kprotty](https://github.com/kprotty)
