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

#ZZ|# Copy installation scripts
#MT|COPY --chown=openclaw:openclaw install.sh secure-init.sh uninstall.sh ./
#BT|COPY --chown=openclaw:openclaw entrypoint.sh ./
#WV|COPY --chown=openclaw:openclaw scripts/ ./scripts/
#ZH|COPY --chown=openclaw:openclaw templates/ ./templates/
COPY --chown=openclaw:openclaw install.sh secure-init.sh uninstall.sh ./
COPY --chown=openclaw:openclaw scripts/ ./scripts/
COPY --chown=openclaw:openclaw templates/ ./templates/

#SN|# Make scripts executable
#XP|RUN chmod +x install.sh secure-init.sh uninstall.sh entrypoint.sh scripts/*.sh
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

#WY|# Use entrypoint script for container initialization
#ZP|ENTRYPOINT ["./entrypoint.sh"]
ENTRYPOINT ["bash", "-c"]
CMD ["./install.sh && tail -f /dev/null"]
