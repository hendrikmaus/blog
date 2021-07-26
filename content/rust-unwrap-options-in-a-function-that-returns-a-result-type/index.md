+++
title = "Rust: How to Unwrap Multiple Required Options"
date = 2021-07-18T11:59:00+00:00
description = "I recently wanted to find a lean solution to unwrapping multiple Option types and fail on the first None I get in a Rust program."

[taxonomies]
tags = ["Post", "Rust", "Software"]

[extra]
author = "***REMOVED***"
+++

Let's say we have a function that returns an `Option`.

```rust
fn get_option() -> Option<bool> {
    Some(true)
}
```

We call it in `main` for this example and print the value using the `dbg!` macro:

```rust
fn main() {
    let b = get_option();
    dbg!(b);
}
```

This will yield:

```shell
[src/main.rs:7] b = Some(
    true,
)
```

Let's say we can only continue if we get `Some`, so we want to throw an error if the `Option` turns out to be `None`.
We could simply call `unwrap()` to get the value, but we'd risk a panic.

> Of course, we could also use `match` or `if let` here, but that is no where I am headed - please bear with me.

Since Rust implemented the `?` operator, the natural thing to do would be to use it on the `Option` and either return the value or a `core::option::NoneError`.

Since `main` currently returns `()` that will not compile:

```txt
error[E0277]: the `?` operator can only be used in a function that returns `Result` or `Option` (or another type that implements `Try`)
 --> src/main.rs:6:13
  |
5 | / fn main() {
6 | |     let b = get_option()?;
  | |             ^^^^^^^^^^^^^ cannot use the `?` operator in a function that returns `()`
7 | |     dbg!(b);
8 | | }
  | |_- this function should return `Result` or `Option` to accept `?`
  |
  = help: the trait `Try` is not implemented for `()`
  = note: required by `from_error`
```

However, `main` can return any `Result` type we want. For application code, the `anyhow` crate is a really lean solution:

```shell
# haven't seen this? install https://crates.io/crates/cargo-edit
cargo add anyhow@1
```

> _How did I know that I want to limit my `Cargo.toml` entry to the major version of the crate and why?_
> 
> I ran `cargo search anyhow` and looked at the latest version. For crates that have a major version, we can limit our `Cargo.toml` entry to `crate_name = "1"` to get all patches (`1.0.0` -> `1.0.3`) and features (`1.0.3` -> `1.1.0`) on `cargo update`. That is safe due to the nature of semantic versioning. For crates which still have a `0.x.x` version, the minor version is treated as major version, hence we'd use `crate_name = "0.1"`.

Now let's have `main` return the `Result` type defined by the `anyhow` crate:

```rust
fn main() -> anyhow::Result<()> {  }
```

The `anyhow` crate provides a single `Error` type that let's us replace almost all calls to `unwrap()` with `?`, thereby allowing us to write much leaner application code.

We can use another helper called `anyhow::Context` to return an error with a custom message, much like `.expect("some message")`, whenever our option turns out to be `None`. So essentially, this allows us to convert an `Option` to a `Result` and add some written context that would be printed to the terminal when failing. The application would not panic anymore.

> Beware that you should not use `anyhow` in library code, because it only defines a single `Error` type, and users of a library wouldn't have anything to match on.

```rust
fn main() -> anyhow::Result<()> {
    use anyhow::Context;
    let b = get_option().context("could not extract option")?;
    dbg!(b);

    Ok(())
}
```

If I'd need to check on multiple `Options` and fail on the first `None` I get, this feels like a neat solution.

When dealing with application-level errors, I find this pattern very useful during rapid prototyping as it allows me to give a hint to what went wrong without littering my code with `unwrap` calls.

> Whenever I use `unwrap` in my code, I will either leave a 'TODO' to revisit later, or a comment that states why `unwrap` is sufficient.
> However, most of the time, where `unwrap` is ok to use, I find myself switching to `expect` instead and will add something like `(...) this should never fail` to its description.

Let's take this one step further and introduce a specific error type, which allows for more flexibility and leverages more of Rust's error handling capabilities. To ease the creation of our own error type, we'll use another crate called `thiserror`:

```shell
cargo add thiserror@1
```

First we're going to create an `Enum` to hold our custom error:

```rust
use thiserror::Error;

#[derive(Error, Debug)]
enum Error {
    #[error("Something went wrong")]
    SomeError,
}
```

> This example is very generic; there is a more realistic one at the end of the article, so stay tuned.

Now we can replace the `context()` call with `ok_or()` to provide the custom error type by converting into a `Result` type:

```rust
fn main() -> anyhow::Result<()> {
    let b = get_option().ok_or(Error::SomeError)?;
    dbg!(b);

    Ok(())
}
```

Now if we'd change the return value of `get_option()` to `None`, the program will print:

```txt
Error: Something went wrong
```

That does not seem terribly useful when calling the function from `main`. However, if we'd be deeper in a binary program, or a library crate, the callee is now able to determine _what_ happened and could try to recover.

The difference becomes more pronounced when passing the created error to the `dbg!` macro:

```txt
# context
[src/main.rs:24] &b = Err(
    could not extract option,
)

# custom error
[src/main.rs:16] &b = Err(
    SomeError,
)
```

The first one is very generic and only contains a description, versus the second one, I could actually match and determine its type like in this more realistic example:

```rust
use thiserror::Error;

#[derive(Error, Debug)]
enum Error {
    #[error("the part has not been described")]
    Description,

    #[error("the part number has not been defined")]
    PartNumber,
}

struct Part {
    width: u32,
    length: u32,
    height: u32,
    description: Option<String>,
    part_number: Option<String>,
}

impl Part {
    fn new() -> Self {
        Self {
            width: 1,
            length: 1,
            height: 1,
            description: None,
            part_number: None,
        }
    }
}

fn add_part_to_inventory(part: &Part) -> Result<(), Error> {
    let description = part.description.as_ref().ok_or(Error::Description)?;
    let part_number = part.part_number.as_ref().ok_or(Error::PartNumber)?;

    println!("Dimensions: {} x {} x {}", part.width, part.height, part.length);
    println!("Part Number: {}", part_number);
    println!("Description: {}", description);

    Ok(())
}

fn main() -> anyhow::Result<()> {
    let part = Part::new();

    match add_part_to_inventory(&part) {
        Ok(()) => println!("part was added to inventory"),
        Err(Error::Description) => {
            // the program could call a machine learning model that can create brief descriptions
            // flag the part for review, and re-submit it to the inventory
            eprintln!("please describe the part before adding it to the inventory")
        }
        Err(Error::PartNumber) => {
            // the program could generate a unique part number and re-submit it to the inventory
            eprintln!("assign a part number before adding the part to the inventory")
        }
    }

    Ok(())
}
```

This program tries to create some sort of part and wants to record all available parts in an inventory. However, a part might be missing a number and a description, as those fields are optional. By using specific error types, the program can determine _what_ failed, try to recover and try again. The behavior is described in comments for the sake of simplicity.

## Conclusion

I especially like to use this approach when dealing with code that needs to unwrap a lot of `Options` which are required to continue with the logic. For example an API call that yields a struct where all fields are optional. However, I need to make sure that all the fields I want to use were actually populated, otherwise I want to raise an error on the first value missing.

I hope this article was useful to you. If so, do not hesitate to leave a comment below and share it with others interested in Rust.

> If you are a more seasoned Rust developer and this is all bogus, please help me by writing a comment below, so I can improve my Rust, thank you.
