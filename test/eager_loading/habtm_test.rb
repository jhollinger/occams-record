require 'test_helper'

class EagerLoadingHabtmTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_habtm_query
    ref = User.reflections.fetch 'offices'
    loader = OccamsRecord::EagerLoaders::Habtm.new(ref, ->(q) { q.order('offices.name DESC') })
    users = [
      OpenStruct.new(id: 1000),
      OpenStruct.new(id: 1001),
    ]
    User.connection.execute "INSERT INTO offices_users (user_id, office_id) VALUES (1000, 100), (1000, 101), (1001, 101), (1001, 102), (1002, 103)"

    loader.send(:query, users) { |scope, join_rows|
      assert_equal %q(SELECT offices.* FROM offices WHERE offices.id IN (100, 101, 102) ORDER BY offices.name DESC), normalize_sql(scope.to_sql.gsub(/\s+/, " "))
      ids = [[1000, 100], [1000, 101], [1001, 101], [1001, 102]]
      ids = ids.map { |x| x.map(&:to_s) } if ar_version == 4 and pg?
      assert_equal ids, join_rows
    }
  end

  def test_habtm_merge
    ref = User.reflections.fetch 'offices'
    loader = OccamsRecord::EagerLoaders::Habtm.new(ref)
    users = [
      OpenStruct.new(id: 1000, username: 'bob'),
      OpenStruct.new(id: 1001, username: 'sue'),
    ]
    User.connection.execute "INSERT INTO offices_users (user_id, office_id) VALUES (1000, 100), (1000, 101), (1001, 101), (1001, 102), (1002, 103)"

    loader.send(:merge!, [
      OpenStruct.new(id: 100, name: 'A'),
      OpenStruct.new(id: 101, name: 'B'),
      OpenStruct.new(id: 102, name: 'C'),
      OpenStruct.new(id: 103, name: 'D'),
    ], users, [[1000, 100], [1000, 101], [1001, 101], [1001, 102]])

    assert_equal [
      OpenStruct.new(id: 1000, username: 'bob', offices: [
        OpenStruct.new(id: 100, name: 'A'),
        OpenStruct.new(id: 101, name: 'B'),
      ]),
      OpenStruct.new(id: 1001, username: 'sue', offices: [
        OpenStruct.new(id: 101, name: 'B'),
        OpenStruct.new(id: 102, name: 'C'),
      ]),
    ], users
  end

  def test_habtm_full_with_order
    users = OccamsRecord.
      query(User.order("username ASC")).
      eager_load(:offices, ->(q) { q.order("name DESC") }).
      run

    assert_equal [
      ["bob", ["Foo", "Bar"]],
      ["craig", ["Foo"]],
      ["sue", ["Zorp", "Bar"]]
    ], users.map { |u|
      [u.username, u.offices.map(&:name)]
    }
  end

  def test_habtm_full_with_order_and_scope_method
    users = OccamsRecord.
      query(User.order("username ASC")).
      eager_load(:offices) {
        scope { |q| q.order("name DESC") }
      }.
      run

    assert_equal [
      ["bob", ["Foo", "Bar"]],
      ["craig", ["Foo"]],
      ["sue", ["Zorp", "Bar"]]
    ], users.map { |u|
      [u.username, u.offices.map(&:name)]
    }
  end

  def test_habtm_makes_empty_arrays_even_if_there_are_no_associated_records
    User.connection.execute "DELETE FROM offices_users"
    results = OccamsRecord.
      query(User.all).
      eager_load(:offices).
      map do |user|
        user.offices
      end
    refute results.any?(&:nil?)
  end

  def test_has_and_belongs_to_many
    users = OccamsRecord.
      query(User.all).
      eager_load(:offices).
      run

    assert_equal 3, users.count
    bob = users.detect { |u| u.username == 'bob' }
    sue = users.detect { |u| u.username == 'sue' }
    craig = users.detect { |u| u.username == 'craig' }

    assert_equal %w(Bar Foo), bob.offices.map(&:name).sort
    assert_equal 2, bob.office_ids.size
    assert_equal %w(Bar Zorp), sue.offices.map(&:name).sort
    assert_equal %w(Foo), craig.offices.map(&:name).sort
  end
end
