FROM ruby:4.0.7-slim

# Native extensions (puma) are compiled during bundle install.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copying only the Gemfiles first lets Docker cache the installed gems
# until the dependencies change, instead of reinstalling on every code edit.
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install

COPY . .

RUN useradd --create-home app && chown -R app:app /app
USER app

EXPOSE 9292

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
