# build shell-operator binary
FROM golang:1.12 AS shell-operator
ARG appVersion=latest

# Cache-friendly download of go dependencies.
ADD "https://raw.githubusercontent.com/flant/shell-operator/master/go.mod" "https://raw.githubusercontent.com/flant/shell-operator/master/go.sum" /src/shell-operator/
WORKDIR /src/shell-operator
RUN go mod download

# COPY --from=libjq /out/build /build
ADD "https://github.com/flant/shell-operator/archive/master.tar.gz" /tmp
RUN ls /tmp \
      mv /tmp/shell-operator-master/* /src/shell-operator/


RUN CGO_ENABLED=1 \
    CGO_CFLAGS="-I/build/jq/include" \
    CGO_LDFLAGS="-L/build/onig/lib -L/build/jq/lib" \
    GOOS=linux \
    go build -ldflags="-s -w -X 'github.com/flant/shell-operator/pkg/app.Version=$appVersion'" \
             -o shell-operator \
             ./cmd/shell-operator



# build final image
FROM debian:stable-slim

ENV DEBIAN_FRONTEND noninteractive
ENV POWERSHELL_TELEMETRY_OPTOUT 1
ENV SHELL_OPERATOR_WORKING_DIR /hooks
ENV LOG_TYPE json

RUN apt-get update; \
        apt-get install -y --no-install-recommends ca-certificates wget jq software-properties-common apt-transport-https unzip gnupg libunwind8 ; \
        apt-get upgrade; \
        apt-get purge -y --auto-remove

# Kubernetes Powershell gcloud
RUN wget --directory-prefix=/usr/share/keyrings https://packages.microsoft.com/keys/microsoft.asc && gpg --dearmor --yes /usr/share/keyrings/microsoft.asc; \
		sh -c "echo 'deb [signed-by=/usr/share/keyrings/microsoft.asc.gpg] https://packages.microsoft.com/repos/microsoft-debian-stretch-prod stretch main' > /etc/apt/sources.list.d/microsoft.list"; \
		wget --directory-prefix=/usr/share/keyrings https://packages.cloud.google.com/apt/doc/apt-key.gpg; \
		sh -c "echo 'deb [signed-by=/usr/share/keyrings/apt-key.gpg] http://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list"; \
		# wget -O /usr/share/keyrings/gcloud-key.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg; \
		# sh -c "echo 'deb [signed-by=/usr/share/keyrings/gcloud-key.gpg] https://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main' >> /etc/apt/sources.list.d/gcloud.list"; \
		apt-get update; \
		apt-get install -y --no-install-recommends powershell kubectl; \
		apt-get purge -y --auto-remove; \
        mkdir /hooks

COPY --from=shell-operator /src/shell-operator /

WORKDIR /

ENTRYPOINT ["/shell-operator"]

CMD ["start"]
