class DownloadsController < ApplicationController
  def episode_mp3
    feed = Feed.find_by!(uid: params[:uid])
    episode = feed.show.episodes.find { |item| item.id.to_s == params[:episode_id].to_s }

    raise ActiveRecord::RecordNotFound if episode.nil?
    raise ActiveRecord::RecordNotFound if replay_excluded?(feed, episode)

    resolver = OhdioSegmentAudioUrlResolver.new(cache: Rails.cache)
    urls = resolver.call(segments: episode.segments)
    raise ActiveRecord::RecordNotFound if urls.empty?

    output_path = RemoteAudioFileJoiner.new(urls: urls).call

    send_file output_path,
              type: "audio/mpeg",
              disposition: "attachment",
              filename: "#{feed.uid}-#{episode.id}.mp3"
  end

  private

  def replay_excluded?(feed, episode)
    feed.exclude_replays && episode.is_replay
  end
end
