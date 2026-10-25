FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends procps python3 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /var/www
ENV LOG_FILE=/var/www/monitor.log
COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh
EXPOSE 8080
CMD ["/bin/bash", "-c", "touch \"$LOG_FILE\" && { /usr/local/bin/script.sh & exec python3 -m http.server 8080; }"]
