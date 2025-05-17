FROM debian:stable-slim

# Install necessary tools
RUN apt-get update && apt-get install -y \
    bash \
    markdown \
    libxml2-utils \
    html-xml-utils \
    rsync \
    ca-certificates \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install scripts to a neutral location
COPY schachtel/dotgen.sh /usr/local/bin/dotgen.sh
COPY schachtel/rdrtpl.sh /usr/local/bin/rdrtpl.sh

# Make them executable
RUN chmod +x /usr/local/bin/dotgen.sh
RUN chmod +x /usr/local/bin/rdrtpl.sh

# Use dotgen.sh as entrypoint
ENTRYPOINT ["/usr/local/bin/dotgen.sh"]
