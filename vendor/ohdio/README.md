# Ohdio

`ohdio` is a Ruby client for the Radio-Canada Ohdio audio streaming API.

## Installation

Via RubyGems:

```
$ gem install ohdio
```

Or add it to a Gemfile:

gem 'ohdio'

## Usage

- [Ohdio](#ohdio)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Fetching a programme](#fetching-a-programme)
  - [Search](#search)
  - [Programme types](#programme-types)
  - [Episodes](#episodes)
  - [Segments](#segments)
  - [Audio URLs](#audio-urls)
  - [Requirements](#requirements)
  - [Development](#development)
  - [Pull request?](#pull-request)
  - [License](#license)

## Fetching a programme

Programme IDs can be extracted from Ohdio URLs. For example, the URL:

```
https://ici.radio-canada.ca/ohdio/episodes/balado/123456
```

Contains the ID `123456`.

```ruby
show = Ohdio::Fetcher.fetch(123456, type: :balado)

show.title       # => "Mon emission"
show.description # => "Description text"
show.type        # => "balado"
show.episodes    # => [#<Ohdio::Episode ...>]
```

If you don't know the programme type, omit it and the client will try each type:

```ruby
show = Ohdio::Fetcher.fetch(123456)
```

## Search

Search returns model objects (`Ohdio::Show`, `Ohdio::Episode`, `Ohdio::Segment`) depending on result type:

```ruby
results = Ohdio::Searcher.search('balado')

results.first.class # => Ohdio::Show / Ohdio::Episode / Ohdio::Segment
```

Filter by category or specific type:

```ruby
Ohdio::Searcher.search('balado', filter: :products)
Ohdio::Searcher.search('balado', filter: :contents)
Ohdio::Searcher.search('balado', filter: :balado)
```

Resolve missing data immediately:

```ruby
results = Ohdio::Searcher.search('balado', resolve: true)
```

Or lazily resolve per object when accessing missing fields:

```ruby
show = Ohdio::Searcher.search('balado', filter: :balado).first
show.description # triggers resolution if needed
```

## Programme types

| Type | Description |
|------|-------------|
| `:balado` | Podcast |
| `:emission_premiere` | Radio show |
| `:grande_serie` | Series |
| `:audiobook` | Audiobook |

Audiobooks do not support pagination:

```ruby
show = Ohdio::Fetcher.fetch(123456, type: :audiobook)
```

For other types, use the `page` option:

```ruby
show = Ohdio::Fetcher.fetch(123456, type: :balado, page: 2)
```

## Episodes

Each episode has:

```ruby
episode = show.episodes.first

episode.id          # => "abc123"
episode.title       # => "Episode title"
episode.description # => "Episode description"
episode.duration    # => 3600 (seconds)
episode.published_at # => "2026-01-15T12:00:00Z"
episode.is_replay   # => false
episode.url         # => "https://ici.radio-canada.ca/ohdio/..."
```

## Segments

Segments (cue sheet) are only available for `:emission_premiere` type. They trigger an additional API call on access:

```ruby
episode = show.episodes.first
episode.segments  # => [#<Ohdio::Segment ...>]

segment = episode.segments.first
segment.title     # => "Segment title"
segment.duration   # => 300 (seconds)
segment.seek_time  # => 120 (seconds)
```

## Audio URLs

Direct audio download URLs are lazily resolved via the media validation API:

```ruby
episode.audio_url  # => "https://medias.mobile.ssl.cdn.rc.ca/..."
```

For `:emission_premiere` (radio shows), audio URLs are only available on segments, not episodes:

```ruby
segment = episode.segments.first
segment.audio_url  # => "https://medias.mobile.ssl.cdn.rc.ca/..."
episode.audio_url  # => nil
```

For `:balado`, `:grande_serie`, and `:audiobook`, use `episode.audio_url` directly.

## Requirements

Ruby >= 3.2

## Development

Tests use VCR to mock API interactions. To run:

```
$ rspec
```

## Pull request?

Yes.

## License

[MIT License](http://opensource.org/licenses/MIT)
