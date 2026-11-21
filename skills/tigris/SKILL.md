---
name: tigris
description: Tigris object storage from app code over the S3 SDK — bucket and key design, public vs private, presigned URLs, caching and stale objects, multipart, the secrets the app reads. Use when a repo calls Tigris (`t3.storage.dev`, a `fly storage` bucket). Provisioning is `fly`'s.
user-invocable: false
---

Claims read from `tigrisdata.com/docs` (its `.md` twin per page) and `docs.fly.io` on 2026-11-21; a rule with no citation is a recipe, and its reason stands beside it. Dates and limits are today's: re-read the cited page before relying on one.

**Tigris is S3 with a global cache in front, and the defaults are private and cached.** An upload that works against a bucket fails later as a 403 on a URL nobody signed, or as yesterday's image under today's key. ([`docs/buckets/create-bucket`](https://www.tigrisdata.com/docs/buckets/create-bucket.md), [`docs/objects/caching`](https://www.tigrisdata.com/docs/objects/caching.md))

## Connect
- **Endpoint `https://t3.storage.dev`, region `auto`.** Credentials come from the environment: `AWS_ACCESS_KEY_ID` (`tid_…`), `AWS_SECRET_ACCESS_KEY` (`tsec_…`), plus the endpoint and region. ([`docs/sdks/s3`](https://www.tigrisdata.com/docs/sdks/s3.md), [`docs/iam/manage-access-key`](https://www.tigrisdata.com/docs/iam/manage-access-key.md))
- A bucket from `fly storage create` carries `fly.storage.tigris.dev` as its endpoint; both reach the same buckets, and Fly names `t3.storage.dev` the one for new code. ([`docs.fly.io/reference/tigris`](https://docs.fly.io/reference/tigris.md))
- **Addressing is virtual-hosted** (the bucket in the hostname): path-style is unsupported for buckets created on or after 2025-02-19. Tigris's JS page sets path-style off, and its multipart page says the same of `t3.storage.dev`. ([`docs/buckets/public-bucket`](https://www.tigrisdata.com/docs/buckets/public-bucket.md), [`docs/sdks/s3/aws-js-sdk`](https://www.tigrisdata.com/docs/sdks/s3/aws-js-sdk.md), [`docs/objects/multipart-uploads`](https://www.tigrisdata.com/docs/objects/multipart-uploads.md))

```ts
const s3 = new S3Client({
  region: process.env.AWS_REGION ?? "auto",
  endpoint: process.env.AWS_ENDPOINT_URL_S3 ?? "https://t3.storage.dev",
});
```

Credentials stay out of the constructor: the SDK's credential chain reads the two key variables. The bucket name is config the app reads (`BUCKET_NAME` from Fly), never a literal.

## Secrets the app reads, by name
| Name | From |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | the access key; the secret is shown once ([`docs/iam/manage-access-key`](https://www.tigrisdata.com/docs/iam/manage-access-key.md)) |
| `AWS_ENDPOINT_URL_S3` | `fly storage create`; currently `https://fly.storage.tigris.dev` per Fly, while Tigris's own sample prints `https://t3.storage.dev` |
| `BUCKET_NAME` | `fly storage create` |
| `AWS_REGION` | **not set by `fly storage create`**; the app defaults to `auto` |

The two vendors document `fly storage create` differently. Run outside an app, it prints all four with values. Run inside an app directory, Tigris's page shows it listing the **names only**, then "Secrets are staged for the first deployment", so there may be no key in the output to capture. A lost key isn't recoverable: `fly storage dashboard <bucket>` opens the console to mint a new one. ([`docs.fly.io/reference/tigris`](https://docs.fly.io/reference/tigris.md), [`docs/buckets/create-bucket`](https://www.tigrisdata.com/docs/buckets/create-bucket.md))

An app key takes the **ReadWrite** role on its one bucket in the `no_default_allow` scope: a key in the `standard` scope can still create and list buckets, and **Admin is for development only**. ([`docs/iam/manage-access-key`](https://www.tigrisdata.com/docs/iam/manage-access-key.md))

## Buckets and keys
- **A bucket name can't change after creation**, so name it for what it holds (`<app>-<env>-uploads`), one bucket per environment. Default location is `global`; single-region, dual-region and `usa`/`eur` multi-region are set with `LocationConstraint` at creation. ([`docs/buckets/create-bucket`](https://www.tigrisdata.com/docs/buckets/create-bucket.md))
- **No dots in a bucket that will be public**: the default public domains' wildcard certificate doesn't cover them. ([`docs/buckets/public-bucket`](https://www.tigrisdata.com/docs/buckets/public-bucket.md))
- **Prefix by purpose and owner** (`avatars/<user-id>/…`, `renders/<job-id>/…`) so one listing, and one ownership check, covers one kind of object. Build the key on the server from ids; a client-supplied filename is a suffix at most.
- **Narrow the app's key.** Neither vendor documents the role or scope of the key `fly storage create` mints, so make the app's own key in the console (`fly storage dashboard <bucket>`). A Dashboard key always starts in the `standard` scope: give it ReadWrite on the one bucket, then turn **Default allowed operations** off. `tigris access-keys create --default-permissions disable`, or `scope: "no_default_allow"` in `@tigrisdata/iam`, sets it at creation. ([`docs/iam/manage-access-key`](https://www.tigrisdata.com/docs/iam/manage-access-key.md), [`docs.fly.io/reference/tigris`](https://docs.fly.io/reference/tigris.md))
- **The key carries the version.** Store a content hash or a generation in the key (`avatars/<user-id>/<hash>.webp`) and save that key in the database. A new upload is a new key, so no cache holds a stale object under it. Overwriting one key is the case the next section breaks.

## Public or private
**Buckets are private by default.** Public means a `public-read` bucket: `fly storage create --public` makes one, and `fly storage update <bucket> --private` turns it back. Objects inherit the bucket's setting, and one object can be set private. An org created after 2026-05-18 needs a verified payment method before any bucket can be public. ([`docs/buckets/public-bucket`](https://www.tigrisdata.com/docs/buckets/public-bucket.md), [`docs/buckets/create-bucket`](https://www.tigrisdata.com/docs/buckets/create-bucket.md), [`docs.fly.io/reference/tigris`](https://docs.fly.io/reference/tigris.md))
- A public object is served at `https://<bucket>.t3.tigrisfiles.io/<key>` (Fly's primary) or the interchangeable `https://<bucket>.t3.tigrisbucket.io/<key>`, never from `t3.storage.dev`, which is the API endpoint. A custom domain is Tigris's recommendation for production. Listing is off by default; the root answers `403`.
- **Public** fits media any visitor sees: rendered video, published images. **Private** fits anything tied to a user, with the app handing out a presigned URL after its own auth check.

## Presigned URLs
Sign on the server with `@aws-sdk/s3-request-presigner`'s `getSignedUrl` over a `GetObjectCommand` or `PutObjectCommand`, with `expiresIn` in seconds. ([`docs/sdks/s3/aws-js-sdk`](https://www.tigrisdata.com/docs/sdks/s3/aws-js-sdk.md), [`docs/objects/presigned`](https://www.tigrisdata.com/docs/objects/presigned.md))
- **Maximum 90 days**; use minutes for a download link and for an upload, and sign again on the next page view. Generate Signature Version 4: V2 URLs are deprecated, still accepted, and slated for removal. The .NET SDK is the one that needs `UseSignatureVersion4 = true`.
- **A signed `x-amz-*` header must be sent by the client with the same value**, and a header the client adds unsigned is rejected. Tigris requires signed `x-amz-*` headers on buckets created after 28 Sep 2026. Pick the headers (an `x-amz-meta-*`, an `x-amz-checksum-*`) before signing and hand them to the browser with the URL.
- **A presigned PUT overwrites an existing key.** The server picks the key (a fresh versioned one) and signs that; the client never chooses it.
- A custom domain on a presigned URL swaps the host after signing. Uploaded HTML, JS or SVG then runs on that domain: restrict the signed `Content-Type`.

## Caching
Caching is on for every bucket with no setting; Tigris returns the cache headers you wrote with the object. A public bucket's static assets (web files, fonts, images, video, audio, PDF) with none written get `Cache-Control: public, max-age=3600`. ([`docs/objects/caching`](https://www.tigrisdata.com/docs/objects/caching.md))
- **Write `Cache-Control` at upload.** A versioned key gets `public, max-age=31536000, immutable`; a key you overwrite gets a short `max-age`, since a browser or proxy keeps the old object for that long and the docs describe no purge.
- **Reads are strongly consistent within a region.** On a `global` or dual-region bucket a read from another region can return the previous version for a sub-second window; multi-region and single-region are strong everywhere. A versioned key keeps a stale *version* from being served, but a reader in another region can still miss a key written moments ago, so pick single-region or multi-region at creation when cross-region read-after-write matters. ([`docs/concepts/consistency`](https://www.tigrisdata.com/docs/concepts/consistency.md))

## Uploads
- **A buffered `PutObjectCommand` holds the whole body in memory**, as the JS page's `readFile` example does. Send big files through `@aws-sdk/lib-storage`'s `Upload`, which splits them into multipart, or let the browser upload to a presigned PUT and save the key after. ([`docs/sdks/s3/aws-js-sdk`](https://www.tigrisdata.com/docs/sdks/s3/aws-js-sdk.md), [`docs/objects/multipart-uploads`](https://www.tigrisdata.com/docs/objects/multipart-uploads.md))
- **Multipart** follows S3 semantics (objects up to 5 TB). `CompleteMultipartUpload` takes the parts **sorted by part number** or fails with `InvalidPartOrder`. Tigris verifies `x-amz-checksum-sha256` and accepts the other algorithms without verifying them, so send SHA-256 when integrity matters. A finished object's ETag is `<md5>-<parts>`, so it isn't the file's MD5. ([`docs/objects/multipart-uploads`](https://www.tigrisdata.com/docs/objects/multipart-uploads.md))
- **Abort the uploads that fail.** Tigris doesn't describe clearing incomplete ones itself: on error call `AbortMultipartUpload`, and list stale ones with `ListMultipartUploads` now and then.

## Not this skill's job
Creating the bucket and setting its secrets on the app (`fly storage create`) is the **`fly`** skill's. Tigris's own `@tigrisdata/storage` SDK and CLI have official agent skills at `github.com/tigrisdata/skills`, and Tigris publishes an `llms.txt` at `tigrisdata.com/docs/llms.txt`; this skill covers the standard S3 SDK only.
