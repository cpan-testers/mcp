FROM perl:5.42

# Default debian image tries to clean APT after an install. We're using
# cache mounts instead, so we do not want to clean it.
RUN rm -f /etc/apt/apt.conf.d/docker-clean

RUN mkdir -p /app
WORKDIR /app

ADD cpanfile ./
RUN --mount=type=cache,target=/root/.cpanm \
  cpanm -v --installdeps --notest .

ADD ./ ./
EXPOSE 3000
CMD perl -Ilib script/cpantesters-mcp-service daemon
