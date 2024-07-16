# HikkaBackup

This application will help you backup your hikka.io lists.

## Compilation

```shell
mix deps.get --only prod
MIX_ENV=prod mix escript.build
```

## Running

The project assumes Cloudflare R2 storage, so set the following env variables

```
export TOKEN="auth cookie from hikka.io"
export CLOUDFLARE_ACCOUNT_ID="cloudflare account id, which is part of the URL"
export S3_ACCESS_KEY_ID="key id"
export S3_SECRET_ACCESS_KEY="access id"
```

and then run the compiled artifact (you should install erlang to be able to run)

```
./hikka_backup
```

## Goals

- Download JSON dumps of anime, manga, novels
- Use S3 storage
