# === BUILDER IMAGE for ACM ===
FROM alpine:3.12 as builder
USER root
WORKDIR /asn1_codec

# add build dependencies
RUN apk add --upgrade --no-cache --virtual .build-deps \
    cmake \
    g++ \
    make \
    bash \
    automake \
    libtool \
    autoconf \
    librdkafka \
    librdkafka-dev \
    flex \
    bison

# Install pugixml
ADD ./asn1_codec/pugixml /asn1_codec/pugixml
RUN cd /asn1_codec/pugixml && mkdir -p build && cd build && cmake .. && make && make install

# Build and install asn1c submodule
ADD ./asn1_codec/asn1c /asn1_codec/asn1c
RUN cd asn1c && test -f configure || autoreconf -iv && ./configure && make && make install

# Make generated files available to the build & compile example
RUN export LD_LIBRARY_PATH=/usr/local/lib
ADD ./asn1_codec/asn1c_combined /asn1_codec/asn1c_combined
RUN cd /asn1_codec/asn1c_combined && bash doIt.sh

# Remove any lingering .asn files
RUN rm -rf /asn1c_codec/asn1c_combined/j2735-asn-files
RUN rm -rf /asn1c_codec/asn1c_combined/semi-asn-files

# Remove duplicate files
RUN rm -rf /asn1c_codec/asn1c_combined/generated-files

# add the source and build files
ADD ./asn1_codec/CMakeLists.txt /asn1_codec
ADD ./asn1_codec/config /asn1_codec/config
ADD ./asn1_codec/include /asn1_codec/include
ADD ./asn1_codec/src /asn1_codec/src
ADD ./asn1_codec/kafka-test /asn1_codec/kafka-test
ADD ./asn1_codec/unit-test-data /asn1_codec/unit-test-data
ADD ./asn1_codec/data /asn1_codec/data
ADD ./asn1_codec/run_acm.sh /asn1_codec
ADD ./asn1_codec/data /asn1_codec/data

# Build acm.
RUN mkdir -p /build && cd /build && cmake /asn1_codec && make


# === Build image for Java ===
FROM maven:3.8-eclipse-temurin-21-alpine as jbuilder

WORKDIR /home

COPY ./asn1-codec-java/pom.xml ./asn1-codec-java/
COPY ./asn1-codec-java/src ./asn1-codec-java/src

WORKDIR /home/asn1-codec-java

RUN mvn clean install -DskipTests


# === RUNTIME IMAGE for Java and ACM ===
# Using Alpine 3.12 because ACM does not compile or run on the latest Alpine (3.19)
FROM alpine:3.12

WORKDIR /home

# Copy java executable
COPY --from=jbuilder /home/asn1-codec-java/target/asn1-codec-java.jar /home

# Copy asn1_codec executable and test files
USER root
WORKDIR /asn1_codec

# add runtime dependencies
RUN apk add --upgrade --no-cache \
    bash \
    librdkafka \
    librdkafka-dev

# copy the built files from the builder
COPY --from=builder /asn1_codec /asn1_codec
COPY --from=builder /build /build

# Add test data. This changes frequently so keep it low in the file.
ADD ./asn1_codec/docker-test /asn1_codec/docker-test

# Put workdir back to Java home
WORKDIR /home


# Install Java 21, not available from apk in Alpine 3.12
# Dockerfile for eclipse-temurin:21-jre-alpine copied from:
# https://github.com/adoptium/containers/blob/057e5aa7581e96b8a2334290e750b329d62abfdf/21/jre/alpine/Dockerfile

ENV JAVA_HOME /opt/java/openjdk
ENV PATH $JAVA_HOME/bin:$PATH

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN set -eux; \
    apk add --no-cache \
        # java.lang.UnsatisfiedLinkError: libfontmanager.so: libfreetype.so.6: cannot open shared object file: No such file or directory
        # java.lang.NoClassDefFoundError: Could not initialize class sun.awt.X11FontManager
        # https://github.com/docker-library/openjdk/pull/235#issuecomment-424466077
        fontconfig ttf-dejavu \
        # utilities for keeping Alpine and OpenJDK CA certificates in sync
        # https://github.com/adoptium/containers/issues/293
        ca-certificates p11-kit-trust \
        # locales ensures proper character encoding and locale-specific behaviors using en_US.UTF-8
        musl-locales musl-locales-lang \
        tzdata \
    ; \
    rm -rf /var/cache/apk/*

ENV JAVA_VERSION jdk-21.0.3+9

RUN set -eux; \
    ARCH="$(apk --print-arch)"; \
    case "${ARCH}" in \
       aarch64|arm64) \
         ESUM='54e8618da373258654fe788d509f087d3612de9e080eb6831601069dbc8a4b2b'; \
         BINARY_URL='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jre_aarch64_alpine-linux_hotspot_21.0.3_9.tar.gz'; \
         ;; \
       amd64|x86_64) \
         ESUM='b3e7170deab11a7089fe8e14f9f398424fd86db085f745dad212f6cfc4121df6'; \
         BINARY_URL='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jre_x64_alpine-linux_hotspot_21.0.3_9.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
    wget -O /tmp/openjdk.tar.gz ${BINARY_URL}; \
    echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
    mkdir -p "$JAVA_HOME"; \
    tar --extract \
        --file /tmp/openjdk.tar.gz \
        --directory "$JAVA_HOME" \
        --strip-components 1 \
        --no-same-owner \
    ; \
    rm -f /tmp/openjdk.tar.gz ${JAVA_HOME}/lib/src.zip;

RUN set -eux; \
    echo "Verifying install ..."; \
    echo "java --version"; java --version; \
    echo "Complete."



ENTRYPOINT ["java", "-jar", "/home/asn1-codec-java.jar"]
#ENTRYPOINT ["tail", "-f", "/dev/null"]