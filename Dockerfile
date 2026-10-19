FROM ruby:4.0.7-slim

# Las extensiones nativas (puma) se compilan durante el bundle install.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar primero solo los Gemfiles permite que Docker cachee las gemas instaladas
# hasta que cambien las dependencias, en vez de reinstalarlas en cada cambio de código.
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install

COPY . .

RUN useradd --create-home app && chown -R app:app /app
USER app

EXPOSE 9292

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
