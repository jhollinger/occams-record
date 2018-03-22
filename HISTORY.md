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
