#!/usr/bin/env node

const LIBRESSL_URL = 'https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/';
// const ../rpmbuild/SOURCES/

const versionCompare = (lhs, rhs) => {
    // {{{
    const updateNum = v => String(v).replace(/[0-9]+/g, num => {
        return ('000000000'.substr(0, 9 - num.length)) + num;
    });
    const lhs_ = updateNum(lhs);
    const rhs_ = updateNum(rhs);
    if (lhs_ == rhs_) {
        return 0;
    }
    return (lhs_ < rhs_) ? -1 : 1;
    // }}}
};

const getLatest = async () => {
    // {{{
    const fetchHtml = async () => {
        return new Promise(resolve => {
            const http = require('https');
            console.warn(`Downloading ${LIBRESSL_URL}`);
            http.get(LIBRESSL_URL, res => {
                const { statusCode } = res;
                const contentType = res.headers['content-type'];

                if (statusCode !== 200) {
                    console.error(`Request failed, status=${statusCode}`);
                    process.exit(1);
                }
                let rawData = '';
                res.on('data', chunk => {
                    rawData += String(chunk);
                });
                res.on('end', () => {
                    console.warn(`Download done.`);
                    resolve(rawData);
                });
                res.on('error', e => {
                    console.error(`Got error: ${e.message}`);
                    process.exit(1);
                });
            });
        });
    };

    const getVersions = indexHtml => {
        const regex = /^<a href="(libressl-([0-9.]+)\.tar\.gz)">/mg;
        const result = [];
        let match;
        while (match = regex.exec(indexHtml)) {
            result.push({
                "version": match[2],
                "fileName": match[1],
                "url": `${LIBRESSL_URL}/${match[1]}`,
            });
        }
        result.sort((a, b) => versionCompare(b.version, a.version));
        return result;
    };

    return getVersions(await fetchHtml()).shift();
    // }}}
};

const downloadArchive = async (url, path) => {
    return new Promise(async resolve => {
        const http = require('https');
        const fs = require('fs');

        const isFileExist = async (path) => new Promise(resolve => {
            fs.stat(path, (err, stat) => {
                if (!err) {
                    resolve(true);
                    return;
                } else if (err.code == 'ENOENT') {
                    resolve(false);
                    return;
                } else {
                    console.error(`Error getting file stats, err=${err.code}, path=${path}`);
                    process.exit(1);
                }
            });
        });

        const fileExists = await isFileExist(path);
        if (fileExists) {
            console.warn(`${path} is ready.`);
            resolve(path);
            return;
        }

        console.warn(`Downloading ${url} to ${path}`);
        const fh = fs.openSync(path + '.download', 'w', 0o644);

        http.get(url, res => {
            if (res.statusCode !== 200) {
                console.error(`Request failed, status=${res.statusCode}`);
                process.exit(1);
            }
            let received = 0;
            res.setEncoding('binary');
            res.on('data', chunk => {
                const buf = Buffer.from(chunk, 'binary');
                received += buf.length;
                fs.writeSync(fh, buf);
                console.warn(`Downloading ... ${received} bytes...`);
            });
            res.on('end', () => {
                console.warn(`Download done.`);
                fs.closeSync(fh);
                console.warn(`Renaming`);
                fs.renameSync(path + '.download', path);
                console.warn(`Rename done.`);
                resolve(path);
            });
            res.on('error', e => {
                console.error(`Got error: ${e.message}`);
                process.exit(1);
            });
        });
    });
};

(async () => {
    const path_ = require('path');
    const version = await getLatest();
    const archivePath = path_.resolve(
        __dirname,
        '../rpmbuild/SOURCES',
        version.fileName
    );
    await downloadArchive(version.url, archivePath);

    console.log(`LIBRESSL_VERSION := ${version.version}`);
})();
