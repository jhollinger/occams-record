### 0.35.0 (2018-11-13)
* Bugfix to eager loading polymorphic associations when a record has a blank "type" column.

### 0.34.0 (2018-11-13)
* When eager loading under a polymorphic association, allow associations that only exist on some types.

### 0.33.0 (2018-11-13)
* Generate `widget_ids` methods if `widgets` is eager loaded. NOTE will not work with `OccamsRecord.sql` unless the model is provided!

### 0.32.0 (2018-10-08)
* Bugfix to eager loading `has_one`s when there are really many.

### 0.31.0 (2018-08-07)
* Bugfix to `eager_load_one` and `eager_load_many`.

### 0.30.0 (2018-08-06)
* Support for `:through` associations! `has_and_belongs_to_many` are temporarily not supported. Polymorphic associations probably will never be.

### 0.29.0 (2018-05-2)
* Add `OccamsRecord::Query#first!`
* Don't include associations in `#to_h` by default.
* Allow Hash-like access for results (both String and Symbol keys)

### 0.28.0 (2018-04-29)
* Implement `==` so that two objects from the same table with the same primary key value are equal.
* Fix `#inspect` in results so it's < 65 chars and will show up in exception messages (https://bugs.ruby-lang.org/issues/8982).
* Add `#to_s` to results to return the originating model name and attributes.

### 0.27.0 (2018-04-27)
* Bugfix to misc eager loaders (empty associations would sometimes be nil instead of an empty array)

### 0.26.0 (2018-04-27)
* Bugfix to habtm eager loading when used with `find_each`/`find_in_batches`.

### 0.25.0 (2018-04-26)
* Bugfix to using ORDER BY when eager loading a `has_and_belongs_to_many` relationship.

### 0.24.0 (2018-04-23)
* Support for ActiveRecord 5.2

### 0.23.0 (2018-04-18)
* Include `Enumerable` in `OccamsRecord::Query` and `OccamsRecord::RawQuery`.
* Fix `OccamsRecord::Query#first` so it doesn't modify the query in place.

### 0.22.0 (2018-04-13)
* Bugfix to `eager_load_one`/`eager_load_many` when there are no parent records.

### 0.21.0 (2018-04-10)
* Bugfix when eager loading many-to-many associations when there are no parent records.

### 0.20.0 (2018-04-03)
* Add `OccamsRecord::Query#count` to return number of rows.
* Allow a block to be given to `OccamsRecord::Query#run` to modify that run's query.
* Clean up error classes. Now just: `OccamsRecord::MissingColumnError`, `OccamsRecord::MissingEagerLoadError`.
* Raise the above errors when a column is missing during eager loading.

### 0.19.0 (2018-03-27)
* Bugfix to eager loading when no parent records were returned.

### 0.18.0 (2018-03-26)
* Bugfix to find each.

### 0.17.0 (2018-03-22)
* Rubygems.org fucked up.

### 0.16.0 (2018-03-22)
* Raise `OccamsRecord::Results::MissingEagerLoadError` if an unloaded association is called.
* Raise `OccamsRecord::Results::MissingColumnSelectError` if an unselected column is called.

### 0.15.0 (2018-03-21)
* Add `eager_load_one` and `eager_load_many` for ad hoc, raw SQL associations.

### 0.14.0 (2018-03-19)
* Change `use:` option to prepend modules instead of including them.

### 0.13.1 (2018-03-19)
* Bugfix to friendly exception edge case

### 0.13.0 (2018-03-19)
* Friendly exceptions when eager loading fails (usually b/c a column wasn't in the `SELECT`).

### 0.12.0 (2018-03-19)
* eager_load should check subclasses for matching associations.
* For booleans in results, add `<field>?` aliases.

### 0.11.0 (2018-03-18)
* Add `find_each` and `find_in_batches` for raw SQL queries.

### 0.10.0 (2018-01-21)
* BREAKING CHANGE to `eager_load`. If you pass it a Proc, that Proc must now accept one argument (an `ActiveRecord::Relation`). You will call `select`, `where`, etc, and any model scopes on it instead of calling them "magically" on nothing.

### 0.9.0 (2018-01-19)
* Allow eager loading `as:` a different attribute name.
* Add `OccamsRecord::Query#first` (returns only one record).

### 0.8.1 (2018-01-09)
* Bugfix to null datetimes

### 0.8.0 (2017-12-29)
* Bugfix - Convert datetime results to local timezone (i.e. `Time.zone`), instead of leaving them as UTC.
* Add support for running raw SQL queries with `OccamsRecord.sql`.

### 0.7.0 (2017-11-05)
* Improvement to selecting columngs by different names, aggregates, etc. wrt to type conversion.

### 0.6.0 (2017-09-11)
* Always append the primary key to the ORDER BY clause when using find_each/find_in_batches.
* Refactor (most) eager loading merge code into a dedicated class.

### 0.5.0 (2017-09-10)
* Add Query#to_a and each, to better match ActiveRecord semantics.

### 0.4.1 (2017-09-09)
* Bugfix to polymorphic belongs_to eager loader. (Edge case. If all instances of an associated type were somehow missing/deleted, and the foreign keys weren't cleaned up, the eager loader would blow up.)

### 0.4.0 (2017-08-29)
* Bugfix to has_and_belongs_to_many eager loader

### 0.3.0 (2017-08-23)
* Add `select:` convenience option to `eager_load`.

### 0.2.0 (2017-08-23)
* Allow `use:` to be passed an array of Modules, instead of just one

### 0.1.0 (2017-08-19)
* Initial release
