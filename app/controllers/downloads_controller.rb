class DownloadsController < ApplicationController
  def episode_mp3
    feed = Feed.find_by!(uid: params[:uid])
    FeedRefreshScheduler.enqueue(feed.show_external_id)

    show = feed.show
    raise ActiveRecord::RecordNotFound if show.nil?
    raise ActiveRecord::RecordNotFound if show.emission_premiere? && feed.segment_query.present?

    episode = feed.filtered_episodes(show: show).find_by!(ohdio_episode_id: params[:episode_id].to_s)

    urls, segments, unresolved = audio_sources_for(feed, show, episode)
    return render_pending if unresolved

    raise ActiveRecord::RecordNotFound if urls.empty? && segments.empty?

    output_path = if segments.any?
      RemoteAudioSegmentJoiner.new(segments: segments).call
    else
      RemoteAudioFileJoiner.new(urls: urls).call
    end

    send_file output_path,
              type: "audio/mpeg",
              disposition: "attachment",
              filename: "#{feed.uid}-#{episode.ohdio_episode_id}.mp3"
  end

  def segment_mp3
    feed = Feed.find_by!(uid: params[:uid])
    FeedRefreshScheduler.enqueue(feed.show_external_id)

    show = feed.show
    raise ActiveRecord::RecordNotFound if show.nil? || !show.emission_premiere?
    raise ActiveRecord::RecordNotFound if feed.segment_query.blank?

    segment, unresolved = selected_segment_for(feed: feed, show: show, segment_id: params[:segment_id])
    return render_pending if unresolved
    raise ActiveRecord::RecordNotFound if segment.nil?

    output_path = RemoteAudioSegmentJoiner.new(segments: [
      {
        url: segment.audio_content.audio_url,
        start_time: segment.seek_time.to_f,
        duration: segment.duration.to_f
      }
    ]).call

    send_file output_path,
              type: "audio/mpeg",
              disposition: "attachment",
              filename: "#{feed.uid}-segment-#{segment.id}.mp3"
  end

  private

  def audio_sources_for(feed, show, episode)
    if show.emission_premiere?
      selected_segments = feed.filtered_segments_for_episode(episode: episode)
      unresolved = selected_segments.any? do |segment|
        segment.audio_content_external_id.present? && (segment.audio_content.nil? || !segment.audio_content.resolved?)
      end

      if feed.segment_query.blank?
        urls = selected_segments.filter_map { |segment| segment.audio_content&.audio_url }
        [ urls, [], unresolved ]
      else
        segments = selected_segments.filter_map do |segment|
          audio_url = segment.audio_content&.audio_url
          next if audio_url.blank?

          {
            url: audio_url,
            start_time: segment.seek_time.to_f,
            duration: segment.duration.to_f
          }
        end
        [ [], segments, unresolved ]
      end
    else
      [ Array(episode.audio_url).compact_blank, [], episode.audio_url.blank? ]
    end
  end

  def render_pending
    response.set_header("Retry-After", "30")
    render plain: "Audio is being prepared, retry shortly", status: :accepted
  end

  def selected_segment_for(feed:, show:, segment_id:)
    episodes = feed.filtered_episodes(show: show)

    episodes.each do |episode|
      segment = feed.filtered_segments_for_episode(episode: episode).find_by(id: segment_id)
      next if segment.nil?

      unresolved = segment.audio_content_external_id.present? && (segment.audio_content.nil? || !segment.audio_content.resolved?)
      return [ segment, unresolved ]
    end

    [ nil, false ]
  end
end
