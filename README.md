# shawn

Reactive streams for Janet programming language.

Goal is to have something like `funcool/potok` but without all the RX cruft.

## Tests

Run tests with `jpm test` or continuously with `watch-test`. For watching you
need `fd` and `entr`.

## Usage

Right now only code is in the `/example` directory. Run it with:

```
janet example/init.janet
```

You will be presented with command prompt, type `h` for help on other commands.

## TODOs

- [ ] @todo add on-error handler
- [ ] @todo add combined and error event test
- [ ] @todo write down philosophy and tech
- [ ] @todo refactor
- [ ] @todo make fiber based only?
- [x] @todo add basic documentation
- [x] @todo add threads
