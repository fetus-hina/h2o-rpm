# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## 概要

[H2O](https://h2o.examp1e.net/) Webserver を RHEL 系(el8 / el9 / el10 / eln)向けに RPM ビルドするリポジトリ。Podman(Rocky Linux / Fedora ELN コンテナ、rootless 前提)内で `rpmbuild` を実行し、成果物を `<dist>.build/` に取り出す。tatsushid/h2o-rpm のフォーク。成果物は https://rpm.fetus.jp/h2o-rolling/ で配布される。

## 読んではいけない・触ってはいけないもの

- `h2o-repo/` — h2o 本体の clone(`prepare.sh` が管理する作業用、巨大)
- `node_modules/`
- `*.build/`, `*.build.bak/` — ビルド成果物(rootless Podman ならビルドしたユーザー所有。Docker 時代のものは root 所有)
- `rpmbuild/SOURCES/*.tar.gz` — Makefile がダウンロードするソース tarball

## よく使うコマンド

```bash
make            # 全ディストリビューション(el8 / el9 / el10 / eln)をビルド
make el9        # 特定ディストリビューションのみビルド
make clean      # ビルド成果物とコンテナイメージを削除
make el9 PULL=always  # ベースイメージを pull し直してビルド(`podman build --pull` に渡る)

./prepare.sh    # バージョン更新(h2o-repo を更新し prepare.ts を実行)
./build.sh      # 全ディストリのビルド + rpmsign 署名(+ 任意でデプロイ)
DEPLOY=1 ./build.sh         # ビルド後 rpm.fetus.jp の h2o-rolling へデプロイ
DEPLOY=1 TEST=1 ./build.sh  # h2o-rolling-testing へデプロイ
```

必要なもの: Podman、Node.js 24 以上(`prepare.ts` を `tsx` で実行)、署名用の GPG 鍵、デプロイ時は `createrepo`。

テストやリンタは存在しない。ビルドが通ること自体が検証手段。

## アーキテクチャ / ビルドフロー

リリースは「バージョン更新 → spec 生成 → コンテナ内ビルド → 署名・デプロイ」の流れ。

1. **`prepare.sh` → `prepare.ts`**(バージョン自動更新)
   - `h2o-repo/` を origin/master に同期し(未 clone なら clone)、`npm ci` の後 `npx tsx prepare.ts` を実行
   - h2o の最新コミットのハッシュとコミット日付(Asia/Tokyo の `YYYYMMDD`)を取得
   - OpenSSL のタグを `git ls-remote` で取得し、`OPENSSL_MINIMUM_VERSION` 以上 `OPENSSL_MAXIMUM_VERSION` 未満(現在は 3.0.0 〜 5.0.0 未満、beta は `OPENSSL_BETA` で制御)の最新版を選ぶ
   - `Makefile` 先頭の `# ---- BEGIN/END VERSION BLOCK ----` 内の変数を書き換え、`rpmbuild/SPECS/changelog` の先頭にエントリを追記する
   - h2o が更新された場合、前回からの間にマージされた h2o の PR タイトルを changelog に列挙する(`%` は `%%` にエスケープ)
   - h2o も OpenSSL も変わっていなければ何もしない。コミット日付が前回と同じなら `H2O_GIT_DATE_REBUILD` がインクリメントされ、変われば 0 に戻る

2. **`Makefile`**(ビルド本体)
   - h2o と OpenSSL のソース tarball を `rpmbuild/SOURCES/` にダウンロード
   - `rpmbuild/SPECS/h2o.spec.in` の `@H2O_GIT_REF@` 等のプレースホルダを sed で置換し、`changelog` を連結して `h2o.spec` を生成
   - `podman build -f Containerfile.<dist> rpmbuild` でイメージをビルドする(ビルドコンテキストは `rpmbuild/` なので、Containerfile 内のパスは `rpmbuild/` からの相対)。イメージビルド中に `rpmbuild -ba` を実行し、`podman create` したコンテナから `podman cp` で `/rpmbuild/RPMS` と `/rpmbuild/SRPMS` を `<dist>.build/` に取り出す
   - `PODMAN`(既定 `podman`)と `PULL`(`podman build --pull` の値、既定 `missing`)で上書き可能
   - 既存の `<dist>.build/` は `<dist>.build.bak/` に退避される

3. **`build.sh`**(リリース)
   - el10 → el9 → el8 → eln の順に `make <dist> PULL=always` でベースイメージを最新化しつつビルドし、debug RPM を除去、鍵 `C9F367D2` で `rpmsign --resign`
   - `DEPLOY=1` で `/var/www/sites/fetus.jp/rpm.fetus.jp/public_html/<h2o-rolling|h2o-rolling-testing>/<dist>/` 配下にコピーし、古いパッケージを世代管理(各 10 世代)した上で `createrepo` を実行し、`md5sum.txt` / `sha1sum.txt` / `sha256sum.txt` を生成

## 編集時の注意

- **`rpmbuild/SPECS/h2o.spec` は生成物**(gitignore 済み)。spec の変更は必ず `h2o.spec.in` に対して行う
- `Makefile` の VERSION BLOCK は `prepare.ts` が機械的に書き換える領域。手で編集しない(フォーマット `KEY := value` を崩すとパースに失敗する)
- OpenSSL は各 RPM に静的リンクされる(`openssl_static`)。対象バージョン範囲やパッケージャ情報は `prepare.ts` 冒頭の Configuration 定数で管理
- ディストリ差分は `Containerfile.<dist>` と spec 内の `%if 0%{?rhel}` 分岐に集約されている
  - eln は Fedora ELN(次期 Enterprise Linux。`%rhel` は 11、`%fedora` は未定義なので spec 上は EL として扱われる)。EL11 で壊れる箇所を前もって見つける目的も兼ねる
  - ベースイメージ: el8〜10 は `quay.io/rockylinux/rockylinux:N`(Rocky 公式。Podman の short-name 解決に依存しないよう完全修飾名で書く。`docker.io/library/rockylinux` は更新停止した古いイメージなので使わない)、eln は `quay.io/fedora/eln:latest`(日付付きタグは更新されていない)
  - dnf のリポジトリは el8〜10 共通の `rpmbuild/container/rocky-mirror.repo`(IIJ → 理研 → 山形大の順に baseurl を列挙、`repo_gpgcheck=1`)を使う。`dnf.conf` の `reposdir` で `/etc/yum.repos.mirror.d` のみを読ませ、標準の `/etc/yum.repos.d`(mirrorlist)は使わない。`rpmbuild/` ごとビルドコンテキストに含まれる。eln は国内ミラーが無いため標準の metalink(`repo_gpgcheck=0`)をそのまま使う
  - `%dist` は `.elN.jp3cki`、eln は `.eln%{eln}.jp3cki`(`Containerfile.<dist>` で `.rpmmacros` に設定)
  - ビルド対象の x86-64 レベル: el8 は `x86-64`、el9 は `x86-64-v2`、el10 と eln は `x86-64-v3`
- リリースコミットはパッケージバージョン文字列(例: `2.3.0-1.git20260610.0.ed7899d1c`)をそのままコミットメッセージにする慣習
