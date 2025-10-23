FROM debian:buster-slim

RUN apt-get update -y && \
    apt-get install -y wget unzip && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip Xray-linux-64.zip && \
    rm Xray-linux-64.zip

COPY config.json /etc/xray/config.json

EXPOSE 8080

CMD ["/Xray", "run", "-c", "/etc/xray/config.json"]