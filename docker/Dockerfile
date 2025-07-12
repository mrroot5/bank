FROM amd64/elixir:1.18.4-otp-28-slim

# Set Locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install required packages
ENV DEBIAN_FRONTEND=noninteractive

# inotify-tools required by live code reloading
RUN mkdir /app && \
    apt update -qq && \
    apt install -y --no-install-recommends inotify-tools \
    build-essential \
    ca-certificates \
    git && \
    apt clean && \
    apt autoclean && \
    rm -rf /var/lib/apt/lists/* && \
    mix local.hex --force && \
    mix local.rebar --force

# Set /app as workdir
WORKDIR /app
