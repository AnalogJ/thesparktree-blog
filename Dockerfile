FROM jekyll/builder:3.4

ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=true \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apk add --no-cache imagemagick-dev

WORKDIR /src/thesparktree-blog
RUN chmod +w -R /src/thesparktree-blog

COPY . .
#RUN gem install bundler:1.11.2
##
#RUN bundle install --jobs=4 --retry=3

RUN jekyll build --destination dist

RUN bundle exec htmlproofer dist --check-html --disable-external --assume-extension
