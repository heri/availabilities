# Manages appointements and openings
class Event < ActiveRecord::Base
  scope :at_week, ->(date) { where('starts_at >= ?', date).where('ends_at <= ?', date + 7) }

  validate :validate_dates

  # Availabilities cache is cleared when an event is changed
  after_save { |_ev| Rails.cache.delete_matched 'avails/events' }

  # Outputs availabilities for 7 days following starts
  def self.availabilities(starts)
    return { errors: { base: "Invalid argument"} } unless starts.instance_of? DateTime
    Rails.cache.fetch("#{starts.to_date}/avails/events", expires_in: 5.minutes) do
      opens = Event.where(weekly_recurring: true, kind: 'opening').where('starts_at < ?', starts + 7)
      ones = Event.where(weekly_recurring: false, kind: 'opening').at_week(starts)
      apps = Event.where(kind: 'appointment').at_week(starts)

      (starts.to_date..(starts + 6).to_date).collect do |date|
        { 
          date: date, 
          slots: sort_and_transform(((slots(opens, date) | slots(ones, date)) - slots(apps, date)))
        }
      end
    end
  end

  private

  # finds timeslots gives a series of events and a weekday
  def self.slots(days, date)
    days.to_a.inject([]) { |sum, day| sum + (day.starts_at.wday == date.wday ? fill(day.starts_at.seconds_since_midnight, day.ends_at.seconds_since_midnight).flatten.compact : []) }
  end

  # returns timeslots with 30mn steps given a starts and ends time
  def self.fill(starts, ends)
    [starts, Event.fill(starts + 1800, ends)] if starts < ends
  end

  def self.sort_and_transform(array)
    array.sort.collect { |t| Time.at(t).utc.strftime("%-k:%M") }
  end

  # event validation
  def validate_dates
    errors.add(:starts_at, 'must be before ends date') if starts_at >= ends_at
    start, ends = starts_at.strftime('%M'), ends_at.strftime('%M')
    errors.add(:starts_at, 'must be 30mn steps') unless start == '00' or start == '30'
    errors.add(:ends_at, 'must be 30mn steps') unless ends == '00' or ends == '30' or ends_at.strftime('%H:%M') == '23:59'
    errors.add(:ends_at, 'must be same day as starts_at') unless starts_at.wday == ends_at.wday
  end
end
