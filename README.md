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

Search for a show from the home page. Once a feed is created, its RSS URL can be added to any podcast application.

## Feed filters

Each feed supports optional filters:

- **Query** — include only episodes whose title matches a search string
- **Segment Query** - include only segement whose title matches a search string
- **Exclude replays** — skip episodes marked as replays

## Requirements

Ruby >= 4.0, FFmpeg

## Pull Request?

Yes.

## License

[MIT License](http://opensource.org/licenses/MIT)
