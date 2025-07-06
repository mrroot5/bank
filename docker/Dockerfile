FROM amd64/elixir:1.18.4-otp-28-slim

# Create required dirs
RUN mkdir /app

# Install required packages
ENV DEBIAN_FRONTEND=noninteractive
ENV APP="/app"

# inotify-tools required by live code reloading
RUN apt update -qq && \
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
