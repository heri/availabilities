require 'test_helper'

# Test recurring openings, non-recurring openings and appointements
class EventTest < ActiveSupport::TestCase

  test 'one simple test example' do
    build_recurring('2014-08-04 09:30', '2014-08-04 12:30')
    build_appointmt('2014-08-11 10:30', '2014-08-11 11:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal Date.new(2014, 8, 10), availabilities[0][:date]
    assert_equal [], availabilities[0][:slots]
    assert_equal Date.new(2014, 8, 11), availabilities[1][:date]
    assert_equal ['9:30', '10:00', '11:30', '12:00'], availabilities[1][:slots]
    assert_equal Date.new(2014, 8, 16), availabilities[6][:date]
    assert_equal 7, availabilities.length
  end

  test 'invalid date' do
    # on met '2014-12-30' au lieu d'une date
    availabilities = Event.availabilities '2014-12-30'
    assert_equal Hash, availabilities.class
    assert_equal 'Invalid argument', availabilities[:errors][:base]
  end

  test 'validations' do
    Event.delete_all
    # duration should not be nil
    event = build_recurring('2014-08-04 09:30', '2014-08-04 09:30')
    assert_not event.valid?
    assert_equal [:starts_at], event.errors.keys

    # event times are always :00 or :30
    event = build_recurring('2014-08-04 09:20', '2014-08-04 09:45')
    assert_not event.valid?
    assert_equal [:starts_at, :ends_at], event.errors.keys
  end

  test 'overlapping' do
    # delete events from previous tests
    Event.delete_all
    build_recurring('2014-08-11 09:30', '2014-08-11 12:30')
    build_recurring('2014-08-11 11:30', '2014-08-11 14:30')
    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    # il ne devrait pas y avoir des slots dédoublés. Devrait aller jusqu'à 14h
    assert_equal ['9:30', '10:00', '10:30', '11:00', '11:30', '12:00', '12:30', '13:00', '13:30', '14:00'], availabilities[1][:slots]

    # + non recurring, + appointement, same day
    build_non_recurring('2014-08-11 14:30', '2014-08-11 15:30')
    build_appointmt('2014-08-11 10:30', '2014-08-11 14:30')
    added = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '10:00', '14:30', '15:00'], added[1][:slots]
  end

  test 'different dates' do
    Event.delete_all
    build_recurring('2014-08-04 09:30', '2014-08-04 10:30')
    build_recurring('2014-08-13 09:30', '2014-08-13 10:00')

    # there should be slots on two different dates
    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '10:00'], availabilities[1][:slots]
    assert_equal ['9:30'], availabilities[3][:slots]
  end

  test 'appointement outside openings' do
    Event.delete_all
    build_recurring('2014-08-10 10:30', '2014-08-10 11:00')
    build_appointmt('2014-08-11 10:30', '2014-08-11 11:30')

    # appointements is outside availabilities, there should be no changes
    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['10:30'], availabilities[0][:slots]
  end

  private

  def build_recurring(starts_at, ends_at)
    Event.create kind: 'opening', starts_at: DateTime.parse(starts_at), ends_at:  DateTime.parse(ends_at), weekly_recurring: true
  end

  def build_non_recurring(starts_at, ends_at)
    Event.create kind: 'opening', starts_at: DateTime.parse(starts_at), ends_at:  DateTime.parse(ends_at), weekly_recurring: false
  end

  def build_appointmt(starts_at, ends_at)
    Event.create kind: 'appointment', starts_at: DateTime.parse(starts_at), ends_at:  DateTime.parse(ends_at), weekly_recurring: false
  end
end
