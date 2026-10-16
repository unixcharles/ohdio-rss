# Logs a "stale" entry when a show has gone noticeably longer than usual without a new episode -
# the symptom of a sync that "succeeds" but no longer picks anything up.
#
# "Usual" is the median gap between the show's recent episodes, so a daily show is flagged after a
# few days while a monthly podcast is not. Shows that have been quiet for very long are assumed to
# have ended and are not flagged, nor are audiobooks/grandes séries (finished, chronological).
class ShowStalenessCheck
  SAMPLE_SIZE = 10
  GAP_MULTIPLIER = 3
  MIN_THRESHOLD = 3.days
  ENDED_AFTER = 90.days

  def self.call(show)
    new(show).call
  end

  def initialize(show)
    @show = show
  end

  def call
    return if @show.chronological_order?

    published = @show.episodes.where.not(published_at: nil).newest_first.limit(SAMPLE_SIZE).pluck(:published_at)
    return if published.size < 2

    latest = published.first
    quiet_for = Time.current - latest
    return if quiet_for > ENDED_AFTER

    usual_gap = median(published.each_cons(2).map { |newer, older| newer - older })
    threshold = [ usual_gap * GAP_MULTIPLIER, MIN_THRESHOLD.to_f ].max
    return if quiet_for <= threshold

    ShowSyncError.safely_record(
      @show,
      kind: "stale",
      message: "No new episode since #{latest.to_date.iso8601} " \
               "(usually one every #{format_gap(usual_gap)})."
    )
  end

  private

  def format_gap(seconds)
    if seconds >= 1.day
      days = (seconds / 1.day).round
      "#{days} #{'day'.pluralize(days)}"
    else
      hours = [ (seconds / 1.hour).round, 1 ].max
      "#{hours} #{'hour'.pluralize(hours)}"
    end
  end

  def median(values)
    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end
