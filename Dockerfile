FROM alpine:3.22
RUN apk update && apk upgrade && apk add bash && apk add curl && apk add wget && apk add git
RUN wget https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 && mv jq-linux64 /usr/local/bin/jq && chmod +x /usr/local/bin/jq
COPY phaset.sh /
ENTRYPOINT ["/phaset.sh"]
