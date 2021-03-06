# build libjq
FROM ubuntu:18.04 AS libjq
ENV BUILDNAME  libjq
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y git ca-certificates && \
    git clone https://github.com/flant/libjq-go /libjq-go && \
    cd /libjq-go && \
    git submodule update --init && \
    /libjq-go/scripts/install-libjq-dependencies-ubuntu.sh && \
    /libjq-go/scripts/build-libjq-static.sh /libjq-go /out


# build shell-operator binary
FROM golang:1.12 AS shell-operator
ENV BUILDNAME shell-oper
ARG appVersion=latest

# Cache-friendly download of go dependencies.
RUN git clone https://github.com/flant/shell-operator.git /src/shell-operator
WORKDIR /src/shell-operator
RUN go mod download

COPY --from=libjq /out/build /build

RUN CGO_ENABLED=1 \
    CGO_CFLAGS="-I/build/jq/include" \
    CGO_LDFLAGS="-L/build/onig/lib -L/build/jq/lib" \
    GOOS=linux \
    go build -ldflags="-s -w -X 'github.com/flant/shell-operator/pkg/app.Version=$appVersion'" \
             -o shell-operator \
             ./cmd/shell-operator



# build final image
FROM debian:stretch-slim
ENV BUILDNAME pwsh-oper
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

ADD hooks /hooks
RUN chmod +x /hooks/*.sh;chmod +x /hooks/*.ps1

WORKDIR /

ENTRYPOINT ["/shell-operator"]

CMD ["start"]
