# Production Docker Deployment Guide

This application includes a production-ready, multi-stage [`Dockerfile`](file:///home/devendra/work/App/Dockerfile) featuring:
- **`jemalloc`** for reduced Ruby memory fragmentation and latency.
- **`Thruster`** HTTP reverse proxy for asset caching and gzip compression.
- **`bin/docker-entrypoint`** for automatic database migrations (`bin/rails db:prepare`) on container boot.
- **Non-root security** running under unprivileged user `rails:1000`.

---

## 1. Prerequisites

Before running the container, ensure you have:
1. **Docker** installed and running on the host machine.
2. **PostgreSQL** database accessible from the container (configured in [`config/credentials/production.yml.enc`](file:///home/devendra/work/App/config/credentials/production.yml.enc)).
3. The **Production Decryption Key** located at `config/credentials/production.key` (or stored in a password manager/secret store).

---

## 2. Build the Docker Image

Build the production image from the project root:

```bash
docker build -t app .
```

---

## 3. Run the Production Container

On your production server (EC2 / VPS):

```bash
docker rm -f app

docker run -d \
  -p 80:80 \
  -e RAILS_MASTER_KEY="<your_production_key_here>" \
  --restart always \
  --name app app
```

Access the application at `http://<SERVER_IP>/up`.

---

## 4. Useful Operations & Container Management

### View Live Logs
Stream real-time Thruster and Rails application logs:
```bash
docker logs -f app
```

### Rails Console
Open a production Rails console inside the running container:
```bash
docker exec -it app bin/rails console
```

### Run Database Migrations Manually
`bin/docker-entrypoint` runs `db:prepare` automatically at startup. To run migrations manually on demand:
```bash
docker exec -it app bin/rails db:migrate
```

### Restart the Container
```bash
docker restart app
```

### Redeploy / Update Container
When new code is pulled:
```bash
# 1. Build the updated image
docker build -t app .

# 2. Force-remove the old container
docker rm -f app

# 3. Launch the new container
docker run -d \
  -p 80:80 \
  -e RAILS_MASTER_KEY="<your_production_key_here>" \
  --restart always \
  --name app app

# 4. Clean up old dangling images
docker image prune -f
```

---

## 5. Credentials Management

### Edit Credentials
* **Development**:
  ```bash
  EDITOR="nano" bin/rails credentials:edit --environment development
  ```
  *(VS Code: `EDITOR="code --wait" bin/rails credentials:edit --environment development`)*

* **Test**:
  ```bash
  EDITOR="nano" bin/rails credentials:edit --environment test
  ```

* **Production**:
  ```bash
  EDITOR="nano" bin/rails credentials:edit --environment production
  ```

### Inspect Decrypted Credentials (View Only)
```bash
bin/rails credentials:show --environment development
bin/rails credentials:show --environment test
bin/rails credentials:show --environment production
```
