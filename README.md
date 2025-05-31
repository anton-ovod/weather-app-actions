# Zadanie 2

## 1. Wykrycie zdarzenia

Workflow uruchamiany jest w dwóch przypadkach:

- Po wypchnięciu nowego taga, który pasuje do wzorca v\* (np. `v1.0.0`),

- Ręcznie, poprzez opcję workflow_dispatch.

```yaml
on:
  push:
    tags:
      - "v*"
  workflow_dispatch:
```

## 2. Zmienne środowiskowe

Zdefiniowane zostały dwie zmienne środowiskowe, które służą do określenia nazw obrazów:

```yaml
env:
  GHCR_IMAGE: ghcr.io/${{ github.repository_owner }}/weather-app-actions
  CACHE_IMAGE: ${{ vars.DOCKERHUB_USERNAME }}/weather-app-actions:cache
```

- `GHCR_IMAGE` – nazwa obrazu publikowanego w GitHub Container Registry,

- `CACHE_IMAGE` – obraz wykorzystywany jako cache na DockerHub.

## 3. Konfiguracja środowiska

### 3.1 Checkout

Pobranie zawartości repozytorium:

```yaml
name: Checkout repository
uses: actions/checkout@v4
```

### 3.2 QEMU

Umożliwienie cross-compilacji:

```yaml
name: Set up QEMU
uses: docker/setup-qemu-action@v3
```

### 3.3 Buildx

Umożliwienie budowy obrazów wieloplatformowych:

```yaml
name: Set up Buildx
uses: docker/setup-buildx-action@v3
```

## 4. Docker metadata

W tej sekcji workflow wykorzystywana jest akcja `docker/metadata-action`, której zadaniem jest automatyczne generowanie tagów i metadanych obrazu kontenera. Ułatwia to późniejsze jego wersjonowanie i identyfikację.

```yaml
name: Extract Docker metadata
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: |
      ${{ env.GHCR_IMAGE }}
    flavor: latest=false
    tags: |
      type=semver,pattern={{version}}
      type=sha,format=short,prefix=sha-
```

### 4.1 Typy tagow i uzasadnienie wyboru

W tym workflow zastosowano dwa uzupełniające się schematy tagowania:

- [`type=semver,pattern={{version}}`](https://github.com/docker/metadata-action/tree/v5/?tab=readme-ov-file#typesemver)

  Ten typ tagowania generuje wersje oparte na semantycznym wersjonowaniu [Semantic Versioning](https://semver.org/).

  Tagi te są czytelne dla ludzi i pozwalają na śledzenie konkretnej wersji aplikacji zgodnie z ustalonym schematem:

  ```yaml
  MAJOR.MINOR.PATCH
  ```

- [`type=sha,format=short,prefix=sha-`](https://github.com/docker/metadata-action/tree/v5/?tab=readme-ov-file#typesha)

  Ten typ tagowania tworzy unikalny tag na podstawie skrótu `SHA` ostatniego commita.

  Ułatwia śledzenie zmian w obrazach pochodzących z tej samej wersji aplikacji.

  Pomocny przy debugowaniu i porównywaniu obrazów między środowiskami (`test`, `prod`).

- `flavor: latest=false`

  Zmienna ta oznacza, że workflow nie nadaje obrazu domyślnego tagu `latest`. Jest to świadoma decyzja, która zwiększa bezpieczeństwo i przewidywalność wdrożeń.

## 5. Logowanie do GitHub oraz DockerHub

Autoryzacja w rejestrach kontenerów:

```yaml
name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GH_TOKEN }}
```

```yaml
name: Log in to DockerHub
  uses: docker/login-action@v3
  with:
    username: ${{ vars.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

## 6. Budowanie obrazu do sprawdzenia

W tym kroku wykonywane jest zbudowanie tymczasowego obrazu Dockera, który zostanie załadowany lokalnie w celu przeprowadzenia analizy bezpieczeństwa. Obraz nie jest jeszcze publikowany ani wypychany do zewnętrznych rejestrów.

To podejście pozwala na wczesne wykrycie zagrożeń jeszcze przed publikacją.

```yaml
name: Build image for scanning
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64
    load: true
    tags: ${{ steps.meta.outputs.tags }}
```

## 7. Docker Scout

Po zbudowaniu tymczasowego obrazu uruchamiane jest narzędzie Docker Scout, które wykonuje analizę bezpieczeństwa obrazu pod kątem znanych podatności (`CVE`).

```yaml
name: Docker Scout CVE Scan
  uses: docker/scout-action@v1
  with:
    command: cves
    image: ${{ env.GHCR_IMAGE }}:${{ steps.meta.outputs.version }}
    only-severities: critical,high
    exit-code: true
```

- `image` – wskazuje obraz do analizy (ten sam, który zbudowano lokalnie w poprzednim kroku),

- `only-severities: critical,high` – ogranicza analizę tylko do najbardziej istotnych podatności, które stanowią bezpośrednie zagrożenie,

- `exit-code: true` – jeśli którakolwiek z wykrytych podatności ma poziom critical lub high, workflow natychmiast zakończy się błędem. Chroni to przed wypuszczeniem niebezpiecznego obrazu do produkcji.

`Docker Scout` został wybrany, ponieważ:

- jest oficjalnie wspierany przez `Docker Inc.` i zintegrowany z Docker CLI oraz ekosystemem GitHub Actions.
- zapewnia prostą konfigurację i użycie, co przyspiesza proces CI/CD.
- umożliwia szybkie wykrywanie najpoważniejszych podatności
- eliminuje potrzebę instalowania zewnętrznych narzędzi

## 8. Finalne budowanie i wypychanie obrazu do GHCR

W tym etapie odbywa się docelowe zbudowanie wieloarchitekturowego obrazu Dockera oraz jego wypchnięcie do GitHub Container Registry.

Warto podkreślić, że wcześniej zbudowany obraz nie jest ponownie budowany od zera – Docker wykorzystuje cache oraz warstwy z wcześniejszego builda, co w połączeniu z [`cache-from`](https://hub.docker.com/repository/docker/antonovod/weather-app-actions/general) znacząco przyspiesza proces. W praktyce oznacza to, że obraz jest tylko tagowany odpowiednimi tagami oraz wypychany do rejestru, bez potrzeby powtarzania kosztownej operacji pełnej budowy.

```yaml
name: Push to GHCR
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64,linux/arm64
    push: true
    cache-from: type=registry,ref=${{ env.CACHE_IMAGE }}
    cache-to: type=registry,ref=${{ env.CACHE_IMAGE }},mode=max
    tags: ${{ steps.meta.outputs.tags }}
```
