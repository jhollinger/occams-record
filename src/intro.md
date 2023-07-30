OccamsRecord provides the power tools that ActiveRecord forgot. Specifically, advanced eager loading capabilities, full support for hand-written SQL, cursors, and high performance for read-only operations. Use it alongside ActiveRecord to unlock the power of your database.

Contribute to OccamsRecord's development at [github.com/jhollinger/occams-record](https://github.com/jhollinger/occams-record/).

Full documentation is available at [rubydoc.info/gems/occams-record](http://www.rubydoc.info/gems/occams-record).


## Occam's Razor & Simplicity

> Do not multiply entities beyond necessity. -- William of Ockham

This definition of simplicity is a core tenant of OccamsRecord. Good libraries are simple, fast, and stay out of your way.

### Fast & read-only

OccamsRecord embraces simplicity by doing *less*. The vast majority of ActiveRecord objects are used *read-only*, yet each prepares and holds internal state *just in case* it's used for writing. By returning results as structs, OccamsRecord offers a baseline **3x-5x speed boost and 2/3 memory reduction**.

### No N+1 problem

OccamsRecord simply refuses to do lazy loading, aka the "N+1 query problem". If you want to use an association, eager load it up-front. While ActiveRecord now supports similar *opt-in* behavior, it still can't beat Occams in speed and the power of defaults.

### No arbitrary limitations

OccamsRecord also embraces simplicity by making things easier for you, the person writing code. ActiveRecord has poor support for hand-written SQL, advanced eager loading scenarios, and advanced database features like cursors. OccamsRecord makes everything simpler by providing all of this in a way that's familiar and easy to use.
