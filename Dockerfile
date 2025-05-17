FROM debian:stable-slim

# Install necessary tools
RUN apt-get update && apt-get install -y \
    bash \
    markdown \
    libxml2-utils \                # for xmllint
    html-xml-utils \              # includes xml2asc, hxnormalize, etc.
    rsync \
    ca-certificates \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the dot script and templates into the image
# Adjust this if your local directory structure differs
COPY dot /usr/local/bin/dotgen.sh
COPY templates/ /usr/local/share/dot/templates/

# Make the script executable
RUN chmod +x /usr/local/bin/dotgen.sh

# Set default working directory inside the container
WORKDIR /data

# Use dot script as entrypoint
ENTRYPOINT ["/usr/local/bin/dotgen.sh"]
