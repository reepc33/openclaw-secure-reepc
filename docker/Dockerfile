FROM node:18-alpine

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    openssl \
    jq \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1000 openclaw \
    && adduser -u 1000 -G openclaw -s /bin/bash -D openclaw

# Set working directory
WORKDIR /home/openclaw

# Copy installation scripts
COPY --chown=openclaw:openclaw install.sh secure-init.sh uninstall.sh ./
COPY --chown=openclaw:openclaw scripts/ ./scripts/
COPY --chown=openclaw:openclaw templates/ ./templates/

# Make scripts executable
RUN chmod +x install.sh secure-init.sh uninstall.sh scripts/*.sh

# Switch to non-root user
USER openclaw

# Install OpenClaw CLI
RUN npm install -g @openclaw/cli

# Expose port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# Entry point
ENTRYPOINT ["bash", "-c"]
CMD ["./install.sh && tail -f /dev/null"]
