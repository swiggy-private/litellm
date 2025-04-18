# Builder stage
FROM 157529275398.dkr.ecr.ap-southeast-1.amazonaws.com/ci-libraries/docker/library/python:3.12-slim AS builder

# Set the working directory to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

RUN ls -ltr /app

RUN ls -ltr /app/docker

### [👇 KEY STEP] ###
# Install Prisma CLI and generate Prisma client
RUN pip install prisma 
RUN prisma generate
### FIN #### 


# Install build dependencies using apt (Debian-based)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    musl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip && \
    pip install build

# Build the package
RUN rm -rf dist/* && python -m build

# There should be only one wheel file now, assume the build only creates one
RUN ls -1 dist/*.whl | head -1

# Install the package
RUN pip install dist/*.whl

# install dependencies as wheels
RUN pip wheel --no-cache-dir --wheel-dir=/wheels/ -r requirements.txt

# Runtime stage
FROM 157529275398.dkr.ecr.ap-southeast-1.amazonaws.com/ci-libraries/docker/library/python:3.12-slim AS runtime

# Update dependencies and clean up
RUN apt-get update

WORKDIR /app

# Copy the built wheel from the builder stage to the runtime stage; assumes only one wheel file is present
COPY --from=builder /app/dist/*.whl .
COPY --from=builder /wheels/ /wheels/
COPY --from=builder /app /app

# Install the built wheel using pip; again using a wildcard if it's the only file
RUN pip install *.whl /wheels/* --no-index --find-links=/wheels/ && rm -f *.whl && rm -rf /wheels

RUN chmod +x docker/entrypoint.sh
RUN chmod +x docker/prod_entrypoint.sh

EXPOSE 4000/tcp

# Set your entrypoint and command
ENTRYPOINT ["docker/prod_entrypoint.sh"]
CMD ["--port", "4000", "--config", "/app/proxy_config.yaml"]
