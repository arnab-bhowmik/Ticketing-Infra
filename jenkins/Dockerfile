# Use a base image with the necessary tools
FROM ubuntu:latest

# Install basic utilities
RUN apt-get update && \
    apt-get install -y \
    curl \
    jq

# Install Skaffold
RUN curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
    install skaffold /usr/local/bin/ && \
    rm skaffold

# Set the working directory
WORKDIR /workspace

# Define an entry point (if needed)
# ENTRYPOINT ["your-entrypoint-command"]

# Set default command (if needed)
# CMD ["your-default-command"]
