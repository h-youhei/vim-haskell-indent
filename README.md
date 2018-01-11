# vim-haskell-indent
for one prefer the coding style exchangeable between space and tab indentation


## indent
### auto increment indent level when previous line end with specific keywords
where, let, in, case of, do, if, then, else, deriving, =, ->, ::, (, [, {

### guard
discriminate among guard, 'or' as logic and 'or' in data

### nested condition, enclosing
if then else, case of, (), [], {}

### start at head of line with type declaration
type, newtype, data, class, instance
```
-- always start at head of line
foo x y =
	x + y

	--cursor was here but
type Foo = Int
```

### module
```haskell
module Foo where
-- no indent

module Foo (
	A,
	B ) where
-- no indent
```

### proper indent with something
where, deriving, infix, function

## alignment
where, let, | in data, enumrate with enclosure and comma
```
foo = (bar, bazz)
	where bar = 0
	      bazz = 1

let a = 0
    b = 1
in a + b

data Foo = One
         | Two
         | Three

foo =
    [ bar
    , bazz
    , pon
    ]
```
