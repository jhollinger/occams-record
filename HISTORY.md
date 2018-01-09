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
