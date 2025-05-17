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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy the dot script and templates into the image
# Adjust this if your local directory structure differs
COPY schachtel/dotgen.sh /root/dotgen.sh
COPY schachtel/rdrtpl.sh /root/rdrtpl.sh

# Make the script executable
RUN chmod +x /root/dotgen.sh
RUN chmod +x /root/rdrtpl.sh

# Use dot script as entrypoint
ENTRYPOINT ["/root/dotgen.sh"]
