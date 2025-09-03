FROM ruby:3.4.3-alpine
RUN apk add --no-cache \
    tzdata \
    build-base \
    yaml-dev \
    linux-headers \
    yarn \
    # SQLite
    sqlite-dev \
    sqlite-libs \
    # MySQL
    mysql-dev \
    mysql-client \
    # PostgreSQL
    postgresql-dev \
    postgresql-client \
    # 実行時に必要
    bash \
    shared-mime-info \
    imagemagick \
    imagemagick-dev \
    graphviz \
    ttf-freefont
    
WORKDIR /workdir
ENV TZ='Asia/Tokyo'

ENV RAILS_ENV="production"
ENV RAILS_LOG_TO_STDOUT=1

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.5.22 && \
    bundle config set --local without 'test development' && \
    bundle install -j4 --retry=3

COPY . .
RUN mkdir -p tmp/pids tmp/sockets

# NOTE: 存在チェック
COPY public/robots.txt ./public/

# Configure the main process to run when running the image
# NOTE: assets:precompileは起動時に実施。SECRET_KEY_BASEが必要な為
CMD ["bash", "-c", "bundle exec rails db:migrate db:seed assets:precompile && bundle exec unicorn -c config/unicorn.rb"]
