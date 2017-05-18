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

  test 'no events' do
    Event.destroy_all
    availabilities = Event.availabilities DateTime.parse('2016-08-10')
    availabilities.each do |a|
      assert_equal [], a[:slots]
    end
  end

  test '23:30 -> 24:00' do
    Event.delete_all
    # convention : une disponibilité jusqu'à la fin de la journée est marqué comme 23:59
    build_recurring('2017-01-01 23:00', '2017-01-01 23:59')
    availabilities = Event.availabilities DateTime.parse('2017-01-01')
    assert_equal ['23:00', '23:30'], availabilities[0][:slots]
    assert_equal 7, availabilities.length
  end

  test 'full day' do
    Event.delete_all
    build_recurring('2017-01-01 00:00', '2017-01-01 23:59')
    availabilities = Event.availabilities DateTime.parse('2017-01-01')
    assert_equal 48, availabilities[0][:slots].length
  end

  # on ne tient pas compte des récurrences futures
  test 'future recurrence' do
    Event.delete_all
    # 1er Mai est un lundi, récurrence 8 Mai aussi un lundi mais semaine d'après
    build_recurring('2017-05-08 09:00', '2017-05-08 10:00')
    availabilities = Event.availabilities DateTime.parse('2017-05-01')
    assert_equal 0, availabilities[0][:slots].length
    assert_equal [], availabilities[0][:slots]

    # même test mais la récurrence est bien dans la même semaine
    Event.delete_all
    Rails.cache.clear
    build_recurring('2017-05-01 09:00', '2017-05-01 10:00')
    availabilities = Event.availabilities DateTime.parse('2017-05-01')
    assert_equal 2, availabilities[0][:slots].length
    assert_equal ['9:00', '9:30'], availabilities[0][:slots] 
 end

  test 'invalid date' do
    # erreur si on met '2014-12-30' au lieu d'une date
    availabilities = Event.availabilities '2014-12-30'
    assert_equal Hash, availabilities.class
    assert_equal 'Invalid argument', availabilities[:errors][:base]
  end

  # l'algorithme ne doit pas être changé par le changement d'heure d'été/hiver
  # et aussi tiendre compte des années bissextiles 
  test 'DST' do
    Event.delete_all
    # DST: changement d'heure d'été à hiver est le dimanche 26 Mars 2017 1:00AM
    build_recurring('2017-03-24 09:30', '2017-03-24 10:30')
    build_appointmt('2017-03-31 10:00', '2017-03-31 10:30')
    availabilities = Event.availabilities DateTime.parse('2017-03-25')
    assert_equal Date.new(2017, 3, 31), availabilities[6][:date]
    assert_equal ['9:30'], availabilities[6][:slots]

    Event.delete_all
    # en 2017 28 février -> 1er Mars
    availabilities = Event.availabilities DateTime.parse('2017-02-25')
    assert_equal Date.new(2017, 3, 1), availabilities[4][:date]

    # en 2016 29 février -> 1er Mars
    availabilities = Event.availabilities DateTime.parse('2016-02-25')
    assert_equal Date.new(2016, 3, 1), availabilities[5][:date]
    
    # en 2015 27 février -> 1er Mars
    availabilities = Event.availabilities DateTime.parse('2015-02-25')
    assert_equal Date.new(2015, 3, 1), availabilities[4][:date]
  end

  test 'validations starts and ends date' do
    Event.delete_all
    # duration should not be nil
    event = build_recurring('2014-08-04 09:30', '2014-08-04 09:30')
    assert_not event.valid?
    assert_equal [:starts_at], event.errors.keys

    # event times are always :00 or :30
    event = build_recurring('2014-08-04 09:20', '2014-08-04 09:45')
    assert_not event.valid?
    assert_equal [:starts_at, :ends_at], event.errors.keys

    # duration > 0
    event = build_recurring('2014-08-04 09:30', '2014-08-04 09:00')
    assert_not event.valid?
    assert_equal [:starts_at], event.errors.keys
    
    # starts_at.wday != ends_at.wday
    event = build_recurring('2014-08-04 09:30', '2014-08-03 09:30')
    assert_not event.valid?
    assert_equal [:starts_at, :ends_at], event.errors.keys

    # ends_at at 23:59 is good
    event = build_recurring('2015-08-04 23:30', '2015-08-04 23:59')
    assert_not event.errors.keys.include?(:ends_at)
    assert event.valid?
  end

  test 'overlapping' do
    # delete events from previous tests
    Event.delete_all
    build_recurring('2014-08-11 09:30', '2014-08-11 12:30')
    build_recurring('2014-08-11 11:30', '2014-08-11 13:30')
    # on rajoute une autre récurrence avant 9:30
    build_recurring('2014-08-04 09:00', '2014-08-04 09:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    # il ne devrait pas y avoir des slots dédoublés. Devrait aller jusqu'à 14h
    # les slots devraient aussi être dans l'ordre avec 9:00 en premier
    assert_equal ['9:00', '9:30', '10:00', '10:30', '11:00', '11:30', '12:00', '12:30', '13:00'], availabilities[1][:slots]

    # + non recurring, + appointement, same day
    build_non_recurring('2014-08-11 14:30', '2014-08-11 15:30')
    build_appointmt('2014-08-11 10:30', '2014-08-11 14:30')
    added = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:00', '9:30', '10:00', '14:30', '15:00'], added[1][:slots]
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
