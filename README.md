# OhdioRSS

`ohdio-rss` is a Rails application that generates RSS feeds from Radio-Canada's [Ohdio](https://ici.radio-canada.ca/ohdio) audio streaming platform.

It supports podcasts, radio shows, series, etc normally only available on Ohdio. Feeds update automatically in the background and can be subscribed to from any podcast application.

## Usage

- [OhdioRSS](#ohdiorss)
  - [Usage](#usage)
  - [Creating a feed](#creating-a-feed)
  - [Feed filters](#feed-filters)
  - [Deployment](#deployment)
  - [Requirements](#requirements)
  - [License](#license)

## Creating a feed

Search for a show from the home page. Once a feed is created, its RSS URL can be added to any podcast application. Feeds can be edited (including their filters) at any time from the feed page.

## Feed filters

Each feed supports optional filters:

- **Episode filters** — a list of keywords, each marked Include or Exclude, matched against episode title/description. An episode is kept if it matches any Include keyword (or there are none) and no Exclude keyword.
- **Segment filters** — the same include/exclude keyword list, matched against segment title instead, for segment-based shows.
- **Exclude replays** — skip episodes marked as replays

While editing a feed's filters, use Preview to see which episodes/segments currently match before saving.

## Requirements

Ruby >= 4.0, FFmpeg

## Pull Request?

Yes.

## License

[MIT License](http://opensource.org/licenses/MIT)
