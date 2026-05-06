FROM ollama/ollama:latest

# Pre-warm script: starts the server in background, pulls the configured
# model, then waits on the server PID so the container stays alive.
COPY pull-and-serve.sh /usr/local/bin/pull-and-serve.sh
RUN chmod +x /usr/local/bin/pull-and-serve.sh

ENTRYPOINT ["/usr/local/bin/pull-and-serve.sh"]
