# collab-counter

> That standard Elm Architecture example you see everywhere but with Firebase!

[Demo](https://passy.github.io/collab-counter)

![](https://i.imgur.com/9cmUHCf.png)

This is a counter powered by Firebase through
[elmfire](https://github.com/ThomasWeiser/elmfire).

## Building

```
make all open
```

## Fun Fact

Because I couldn't figure out how to store non-monoidal data structures
with Elmfire, I ended up using a CRDT to store the vote events. That's
fun and all, but I don't think this would gonna scale very well.
