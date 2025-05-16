# Zadanie niobowiązkowe

## 1. Docker Scout

```bash
docker scout cves --only-severity critical,high antonovod/weather-app
```

## ![Image](./screenshots/scout%20result.png)

## 2. Utworzenie buildera

```bash
docker buildx create --driver docker-container --name mybuilder --use --bootstrap
```

![Image](./screenshots/builder%20create.png)

---

## 3. Budowanie obrazu

```bash
docker buildx build
--ssh ssh_key=./docker_lab \
--secret id=pat_token,src=./docker_pat.txt \
--platform linux/amd64,linux/arm64 \
--output type=registry,name=docker.io/antonovod/weather-app \
--cache-to type=registry,ref=docker.io/antonovodcache:weather-app,mode=max \
--cache-from type=registry,ref=docker.io/antonovod/cache:weather-app .
```

## ![Image](./screenshots/docker%20build.png)

## 4. Wynik budowania

### 4.1 Obraz

![Image](./screenshots/wynik%20budowania.png)

### 4.2 Cache

## ![Image](./screenshots/cache.png)

## 5. Sprawdzenie platform

![Image](./screenshots/platforms%20result.png)

---
