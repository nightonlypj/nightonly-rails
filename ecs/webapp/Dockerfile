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
    ttf-freefont \
    # Nginx
    nginx \
    gettext

WORKDIR /workdir
ENV TZ='Asia/Tokyo'

ENV RAILS_ENV="production"
ENV RAILS_LOG_TO_STDOUT=1

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.7.2 && \
    bundle config set --local without 'test development' && \
    bundle install -j4 --retry=3

COPY . .
RUN mkdir -p tmp/pids tmp/sockets

# NOTE: 存在チェック
COPY public/robots.txt ./public/

COPY ecs/web/nginx/nginx.conf.template /etc/nginx/
COPY ecs/web/nginx/conf.d/default.conf.template /etc/nginx/conf.d/
COPY ecs/webapp/nginx/conf.d/unicorn.conf /etc/nginx/conf.d/
COPY public/_check /usr/share/nginx/html/

# Add a script to be executed every time the container starts.
COPY ecs/web/entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Configure the main process to run when running the image
# NOTE: assets:precompileは起動時に実施。SECRET_KEY_BASEが必要な為
CMD ["bash", "-c", "nginx && bundle exec rails db:migrate db:seed assets:precompile && bundle exec unicorn -c config/unicorn.rb"]
